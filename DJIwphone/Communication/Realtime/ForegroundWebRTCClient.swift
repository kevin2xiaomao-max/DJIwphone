import AVFoundation
import Combine
import Foundation
import WebRTC

enum ForegroundWebRTCError: LocalizedError {
    case invalidAnswer
    case http(Int)
    case timeout
    case peerUnavailable
    case operation(String)

    var errorDescription: String? {
        switch self {
        case .invalidAnswer: return "Gateway 返回的 WebRTC answer 无效。"
        case .http(let status): return "WebRTC signaling HTTP \(status)。"
        case .timeout: return "WebRTC ICE 连接超时。"
        case .peerUnavailable: return "WebRTC peer connection 不可用。"
        case .operation(let message): return message
        }
    }
}

private struct ForegroundWebRTCAnswer: Decodable {
    let type: String
    let sdp: String
}

/// Foreground-only audio test client. It is intentionally separate from call
/// control and never opens QDC507 PCM, D4/D5/D6, or USB audio paths.
final class ForegroundWebRTCClient: NSObject, ObservableObject {
    enum Phase: String { case stopped = "Stopped", connecting = "Connecting", connected = "Connected", failed = "Failed" }

    @Published private(set) var phase: Phase = .stopped
    @Published private(set) var peerState = "new"
    @Published private(set) var iceState = "new"
    @Published private(set) var remoteAudioReceived = false
    @Published private(set) var lastError: String?

    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory()
        )
    }()

    private var peerConnection: RTCPeerConnection?
    private var microphoneTrack: RTCAudioTrack?
    private var urlSession: URLSession?

    func start(configuration: GatewayConfiguration) async {
        stop()
        update { $0.phase = .connecting; $0.lastError = nil }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playAndRecord, mode: .voiceChat,
                                  options: [.allowBluetooth, .defaultToSpeaker])
            try audio.setActive(true)

            let rtcConfiguration = RTCConfiguration()
            rtcConfiguration.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
            let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                                   optionalConstraints: ["DtlsSrtpKeyAgreement": "true"])
            guard let peer = Self.factory.peerConnection(with: rtcConfiguration,
                                                          constraints: constraints, delegate: self) else {
                throw ForegroundWebRTCError.peerUnavailable
            }
            peerConnection = peer
            let source = Self.factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil,
                                                                               optionalConstraints: nil))
            let track = Self.factory.audioTrack(with: source, trackId: "djiwphone-foreground-mic")
            microphoneTrack = track
            peer.add(track, streamIds: ["djiwphone-foreground-audio"])

            let offer = try await makeOffer(peer: peer, constraints: constraints)
            try await setLocalDescription(peer: peer, description: offer)
            try await waitForICE(peer: peer)
            guard let localDescription = peer.localDescription else {
                throw ForegroundWebRTCError.operation("本地 SDP 未准备完成。")
            }
            let answer = try await sendOffer(localDescription.sdp, configuration: configuration)
            try await setRemoteDescription(peer: peer, description: answer)
            try await waitForConnected(peer: peer)
            update { $0.phase = .connected }
        } catch {
            stop()
            update { $0.phase = .failed; $0.lastError = error.localizedDescription }
        }
    }

    func stop() {
        peerConnection?.close()
        peerConnection = nil
        microphoneTrack = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        update {
            $0.phase = .stopped
            $0.peerState = "closed"
            $0.iceState = "closed"
            $0.remoteAudioReceived = false
        }
    }

    private func makeOffer(peer: RTCPeerConnection, constraints: RTCMediaConstraints) async throws -> RTCSessionDescription {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peer.offer(for: constraints) { description, error in
                if let error { continuation.resume(throwing: error) }
                else if let description { continuation.resume(returning: description) }
                else { continuation.resume(throwing: ForegroundWebRTCError.operation("无法创建 SDP offer。")) }
            }
        }
    }

    private func setLocalDescription(peer: RTCPeerConnection, description: RTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peer.setLocalDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func setRemoteDescription(peer: RTCPeerConnection, description: RTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { continuation in
            peer.setRemoteDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func waitForICE(peer: RTCPeerConnection) async throws {
        let deadline = Date().addingTimeInterval(15)
        while peer.iceGatheringState != .complete {
            if Date() >= deadline { throw ForegroundWebRTCError.timeout }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func waitForConnected(peer: RTCPeerConnection) async throws {
        let deadline = Date().addingTimeInterval(20)
        while peer.iceConnectionState != .connected && peer.iceConnectionState != .completed {
            if peer.iceConnectionState == .failed || peer.iceConnectionState == .closed {
                throw ForegroundWebRTCError.operation("ICE 状态：\(peer.iceConnectionState.rawValue)。")
            }
            if Date() >= deadline { throw ForegroundWebRTCError.timeout }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private func sendOffer(_ sdp: String, configuration: GatewayConfiguration) async throws -> RTCSessionDescription {
        let request = try configuration.webrtcOfferRequest(sdp: sdp)
        let session = URLSession(configuration: .ephemeral)
        urlSession = session
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ForegroundWebRTCError.invalidAnswer }
        guard (200..<300).contains(http.statusCode) else { throw ForegroundWebRTCError.http(http.statusCode) }
        let answer = try JSONDecoder().decode(ForegroundWebRTCAnswer.self, from: data)
        guard answer.type == "answer", !answer.sdp.isEmpty else { throw ForegroundWebRTCError.invalidAnswer }
        return RTCSessionDescription(type: .answer, sdp: answer.sdp)
    }

    private func update(_ body: @escaping (ForegroundWebRTCClient) -> Void) {
        if Thread.isMainThread { body(self) }
        else { DispatchQueue.main.async { [weak self] in if let self { body(self) } } }
    }
}

extension GatewayConfiguration {
    func webrtcOfferRequest(sdp: String) throws -> URLRequest {
        var request = try self.request(path: "api/webrtc/offer")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["type": "offer", "sdp": sdp])
        return request
    }
}

extension ForegroundWebRTCClient: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        guard let track = stream.audioTracks.first else { return }
        track.isEnabled = true
        update { $0.remoteAudioReceived = true }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        update { $0.iceState = String(describing: newState) }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

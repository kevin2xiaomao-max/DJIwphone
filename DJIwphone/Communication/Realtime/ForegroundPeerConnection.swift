import Foundation
import WebRTC

enum DJIwphoneWebRTCDependency {
    // Keep the linked WebRTC framework in the device product; the peer adapter
    // owns the concrete factory once signaling negotiation is enabled.
    static let factoryType = RTCPeerConnectionFactory.self
}

@MainActor
protocol ForegroundPeerConnection: AnyObject {
    func createOffer() async throws -> String
    func applyAnswer(_ sdp: String) async throws
    func addRemoteCandidate(_ candidate: String) async throws
    func close()
}

struct WebRTCNegotiatedAudioFormat: Equatable {
    let codec: String
    let clockRate: Int
    let channels: Int
}

@MainActor
final class UnconfiguredForegroundPeerConnection: ForegroundPeerConnection {
    private(set) var isClosed = false

    func createOffer() async throws -> String {
        guard !isClosed else { throw URLError(.cancelled) }
        throw URLError(.unsupportedURL)
    }

    func applyAnswer(_ sdp: String) async throws {
        guard !isClosed, !sdp.isEmpty else { throw URLError(.badURL) }
    }

    func addRemoteCandidate(_ candidate: String) async throws {
        guard !isClosed, !candidate.isEmpty else { throw URLError(.badURL) }
    }

    func close() { isClosed = true }
}

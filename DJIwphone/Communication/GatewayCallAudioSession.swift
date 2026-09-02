import Foundation
import Observation

enum GatewayCallAudioState: String, Sendable {
    case idle, incoming, ringing, answering, active, ending, ended, failed
}

@MainActor
@Observable
final class GatewayCallAudioSession {
    private(set) var state: GatewayCallAudioState = .idle
    private(set) var sessionID: String?
    private(set) var lastError: String?
    private var seenEventKeys: Set<String> = []

    func apply(callID: String, event: GatewayAudioEventType, state callState: String? = nil) {
        let key = "\(callID):\(event.rawValue):\(callState ?? "")"
        guard seenEventKeys.insert(key).inserted else { return }
        switch event {
        case .incoming: state = .incoming
        case .ringing: state = .ringing
        case .answered:
            state = .answering
            sessionID = callID
        case .start: state = .answering
        case .ready: state = .active
        case .error:
            state = .failed
            lastError = "Gateway 音频会话启动失败"
        case .stop, .ended:
            state = .ended
            sessionID = nil
        }
    }

    func disconnect() {
        state = .failed
        lastError = "Gateway 连接已断开，音频会话已安全关闭"
        sessionID = nil
    }

    func reset() {
        state = .idle
        sessionID = nil
        lastError = nil
        seenEventKeys.removeAll()
    }
}

import Foundation

@MainActor
final class CallCoordinator {
    private let callKit: DJIwphoneCallKitReporting
    private var ended: Set<String> = []

    init(callKit: DJIwphoneCallKitReporting) { self.callKit = callKit }

    func apply(_ event: GatewayCallEvent) {
        switch event.state {
        case "incoming":
            callKit.reportIncoming(callID: event.callID, handle: event.number ?? "QDC507")
        case "active":
            callKit.reportConnected(callID: event.callID)
        case "ended", "failed", "busy", "no_answer":
            guard ended.insert(event.callID).inserted else { return }
            callKit.reportEnded(callID: event.callID)
        default:
            break
        }
    }
}

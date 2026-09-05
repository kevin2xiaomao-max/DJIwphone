import XCTest
@testable import DJIwphone

@MainActor
final class CallCoordinatorTests: XCTestCase {
    private final class Reporter: DJIwphoneCallKitReporting {
        var incoming: [String] = []
        var connected: [String] = []
        var ended: [String] = []
        func reportIncoming(callID: String, handle: String) { incoming.append(callID) }
        func reportConnected(callID: String) { connected.append(callID) }
        func reportEnded(callID: String) { ended.append(callID) }
    }

    func testIncomingThenEndedUsesOneStableCallIDAndIgnoresDuplicateEnd() {
        let reporter = Reporter()
        let coordinator = CallCoordinator(callKit: reporter)
        let id = String(repeating: "a", count: 32)
        coordinator.apply(GatewayCallEvent(type: "call.ringing", callID: id, state: "incoming", number: "***00"))
        coordinator.apply(GatewayCallEvent(type: "call.ended", callID: id, state: "ended", number: nil))
        coordinator.apply(GatewayCallEvent(type: "call.ended", callID: id, state: "ended", number: nil))
        XCTAssertEqual(reporter.incoming, [id])
        XCTAssertEqual(reporter.ended, [id])
    }
}

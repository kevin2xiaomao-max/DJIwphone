import XCTest
@testable import QDC507Communication

@MainActor
final class GatewayCallAudioSessionTests: XCTestCase {
    func testMockIncomingAnswerAudioHangupLifecycle() {
        let session = GatewayCallAudioSession()
        session.apply(callID: "mock", event: .incoming)
        session.apply(callID: "mock", event: .ringing)
        session.apply(callID: "mock", event: .answered)
        session.apply(callID: "mock", event: .start)
        session.apply(callID: "mock", event: .ready)
        XCTAssertEqual(session.state, .active)
        session.apply(callID: "mock", event: .ended)
        XCTAssertEqual(session.state, .ended)
        XCTAssertNil(session.sessionID)
    }

    func testDuplicateAndFailureAreFailClosed() {
        let session = GatewayCallAudioSession()
        session.apply(callID: "mock", event: .answered)
        session.apply(callID: "mock", event: .answered)
        session.apply(callID: "mock", event: .error)
        XCTAssertEqual(session.state, .failed)
        XCTAssertNotNil(session.lastError)
        session.disconnect()
        XCTAssertEqual(session.state, .failed)
    }
}

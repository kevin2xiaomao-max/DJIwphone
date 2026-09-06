import XCTest
@testable import DJIwphone

@MainActor
final class CallMediaCoordinatorTests: XCTestCase {
    private final class Audio: DJIwphoneAudioSessionControlling {
        var activations = 0; var deactivations = 0
        func activate() throws { activations += 1 }
        func deactivate() { deactivations += 1 }
    }
    private final class Peer: DJIwphonePeerConnection { var closes = 0; func close() { closes += 1 } }

    func testActiveCallActivationAndStopAreIdempotent() throws {
        let audio = Audio(); let peer = Peer()
        let coordinator = CallMediaCoordinator(audio: audio, peer: peer)
        try coordinator.start(callID: "call")
        try coordinator.start(callID: "call")
        coordinator.stop(callID: "call")
        coordinator.stop(callID: "call")
        XCTAssertEqual(audio.activations, 1)
        XCTAssertEqual(audio.deactivations, 1)
        XCTAssertEqual(peer.closes, 1)
    }
}

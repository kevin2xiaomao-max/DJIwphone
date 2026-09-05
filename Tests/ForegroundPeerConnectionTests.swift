import XCTest
@testable import DJIwphone

@MainActor
final class ForegroundPeerConnectionTests: XCTestCase {
    func testPeerCloseIsIdempotentAndRejectsFurtherNegotiation() async {
        let peer = UnconfiguredForegroundPeerConnection()
        peer.close(); peer.close()
        do { _ = try await peer.createOffer(); XCTFail("closed peer must reject offers") }
        catch { XCTAssertTrue(peer.isClosed) }
    }
}

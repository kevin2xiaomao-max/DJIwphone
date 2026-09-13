import XCTest
@testable import DJIwphone

@MainActor
final class ForegroundPeerConnectionTests: XCTestCase {
    func testOfferRequestPreservesBearerSDPAndQDCIPCMode() throws {
        let configuration = try GatewayConfiguration(
            address: "https://gateway.example.com",
            token: "synthetic-test-token"
        )

        let request = try configuration.webrtcOfferRequest(sdp: "test-offer-sdp")
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String]
        )

        XCTAssertEqual(request.url?.path, "/api/webrtc/offer")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-test-token")
        XCTAssertEqual(body["type"], "offer")
        XCTAssertEqual(body["sdp"], "test-offer-sdp")
        XCTAssertEqual(body["media_mode"], "qdc-ipc")
    }

    func testPeerCloseIsIdempotentAndRejectsFurtherNegotiation() async {
        let peer = UnconfiguredForegroundPeerConnection()
        peer.close(); peer.close()
        do { _ = try await peer.createOffer(); XCTFail("closed peer must reject offers") }
        catch { XCTAssertTrue(peer.isClosed) }
    }
}

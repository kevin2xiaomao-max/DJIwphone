import XCTest
@testable import DJIwphone

@MainActor
final class GatewayRealtimeSignalingTests: XCTestCase {
    func testRealtimeRequestUsesExistingWebSocketURLAndBearerToken() throws {
        let token = UUID().uuidString
        let config = try GatewayConfiguration(address: "http://192.168.1.97:17576", token: token)
        let request = try config.realtimeRequest()
        XCTAssertEqual(request.url?.absoluteString, "ws://192.168.1.97:17576/ws")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(token)")
    }

    func testDecodesTypeEnvelopeAndCallID() throws {
        let data = Data(#"{"type":"call.ringing","sequence":7,"data":{"call_id":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","state":"incoming","masked_number":"***00"}}"#.utf8)
        let event = try JSONDecoder().decode(GatewayRealtimeEvent.self, from: data)
        XCTAssertEqual(event.type, "call.ringing")
        XCTAssertEqual(event.data?.callID, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        XCTAssertEqual(event.callEvent?.number, "***00")
    }
}

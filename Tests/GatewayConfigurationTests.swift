import Foundation

// Standalone macOS 14+ Swift harness; no project edits, Gateway or hardware access.
@MainActor
private final class MemoryTokenStorage: GatewayTokenStorage {
    var values: [String: String] = [:]
    var failWrites = false
    func read(account: String) throws -> String? { values[account] }
    func save(_ token: String, account: String) throws {
        if failWrites { throw GatewayClientError.keychain(-1) }
        values[account] = token
    }
}

@main
struct GatewayConfigurationTests {
    @MainActor
    static func main() throws {
        var checks = 0
        func expect(_ condition: Bool) {
            precondition(condition, "Gateway behavior assertion failed")
            checks += 1
        }
        func rejects(_ operation: () throws -> Void) {
            do { try operation(); preconditionFailure("Expected rejection") }
            catch { checks += 1 }
        }
        let suite = "GatewayTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vault = MemoryTokenStorage()
        let settings = GatewaySettingsStore(defaults: defaults, tokenStorage: vault)
        let testToken = UUID().uuidString // synthetic, never a user's token
        try settings.save(address: " http://192.168.1.97:17576/ ", token: testToken)
        let config = try settings.configuration()
        expect(config.baseURL.absoluteString == "http://192.168.1.97:17576")
        let request = try config.request(path: "api/status")
        expect(request.url?.path == "/api/status")
        expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + testToken)
        expect(request.url?.query == nil)
        expect(request.httpMethod == "GET")
        expect(try config.request(path: "ws", webSocket: true).url?.scheme == "ws")
        expect(defaults.persistentDomain(forName: suite)?.count == 1)
        expect(defaults.persistentDomain(forName: suite)?.values.contains(where: { ($0 as? String) == testToken }) == false)
        let reopened = GatewaySettingsStore(defaults: defaults, tokenStorage: vault)
        expect(try reopened.configuration().request(path: "api/status").value(forHTTPHeaderField: "Authorization") == "Bearer " + testToken)
        try reopened.save(address: settings.savedAddress, token: "") // preserve only same-origin credential
        rejects { _ = try reopened.configuration(address: "http://192.168.1.98:17576", token: "") }
        for bad in ["", "ftp://192.168.1.97", "http://user:secret@192.168.1.97", "http://192.168.1.97?token=x", "http://192.168.1.97#x", "http://192.168.1.97/api", "http://8.8.8.8", "http://192.168.1.97:0"] {
            rejects { _ = try GatewayConfiguration(address: bad, token: testToken) }
        }
        rejects { _ = try GatewayConfiguration(address: settings.savedAddress, token: "a\r\nb") }
        rejects { _ = try config.request(path: "api/calls/dial") }
        vault.failWrites = true
        rejects { try settings.save(address: "http://192.168.1.98:17576", token: testToken) }
        expect(settings.savedAddress == "http://192.168.1.97:17576")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        // Shape from the already verified real Gateway; no personal data.
        let statusJSON = #"{"online":true,"port":"COM3","simulated":false,"sim":"READY","operator":"CHN-CT","registration":1,"signal":{"csq":29,"dbm":-55},"updated_at":1788191915.24}"#
        let status = try decoder.decode(GatewayDeviceStatus.self, from: Data(statusJSON.utf8))
        expect(status.registration == "1")
        expect(status.signalStrength == "29")
        expect(status.online && status.simulated == false)
        let eventJSON = "{\"type\":\"device.status\",\"sequence\":1,\"data\":" + statusJSON + "}"
        let event = try decoder.decode(GatewayEvent.self, from: Data(eventJSON.utf8))
        expect(event.data?.deviceStatus == status)
        let callJSON = #"{"items":[{"id":"test-call","direction":"incoming","state":"ended","masked_number":"***00","started_at":1000,"ended_at":1010}]}"#
        let calls = try decoder.decode(GatewayListResponse<GatewayCall>.self, from: Data(callJSON.utf8))
        expect(calls.items.first?.timestamp == Date(timeIntervalSince1970: 1000))
        let smsJSON = #"{"items":[{"id":"synthetic-message","sender":"test-sender","body":"测试短信","sent_at":"2026-09-01T00:00:00+08:00","received_at":1000,"verification_code":null,"encoding":"ucs2","part_count":1}]}"#
        let messages = try decoder.decode(GatewayListResponse<GatewaySMSMessage>.self, from: Data(smsJSON.utf8))
        expect(messages.items.first?.body == "测试短信")
        expect(messages.items.first?.receivedAt == Date(timeIntervalSince1970: 1000))
        expect(messages.items.first?.isVerificationCode == false)
        expect(calls.items.first?.stateTitle == "已结束")
        expect(calls.items.first?.isOngoing == false)
        expect(status.allowedCallActions.isEmpty) // Older Gateway must fail closed.
        let capable = try decoder.decode(GatewayDeviceStatus.self, from: Data(#"{"online":true,"simulated":false,"allowed_call_actions":["answer","reject","hangup","dial"]}"#.utf8))
        expect(capable.allowedCallActions == ["answer", "reject", "hangup", "dial"])
        let requestID = UUID()
        let callID = String(repeating: "a", count: 32)
        for action in [GatewayCallAction.answer, .reject, .hangup] {
            let post = try config.callRequest(action: action, callID: callID, number: nil, requestID: requestID)
            expect(post.httpMethod == "POST")
            expect(post.url?.path == "/api/calls/\(callID)/\(action.rawValue)")
            expect(post.value(forHTTPHeaderField: "Authorization") == "Bearer " + testToken)
            expect(post.value(forHTTPHeaderField: "X-Request-ID") == requestID.uuidString)
            let body = try JSONSerialization.jsonObject(with: post.httpBody!) as! [String: Any]
            expect(body.isEmpty)
        }
        let dial = try config.callRequest(action: .dial, callID: nil, number: "+15551234567", requestID: requestID)
        let dialBody = try JSONSerialization.jsonObject(with: dial.httpBody!) as! [String: Any]
        expect(dialBody["number"] as? String == "+15551234567")
        expect(dialBody["confirmed"] as? Bool == true)
        for bad in ["1234", "12345\n", "１２３４５", "12345;", "12345\rATA", "++12345"] {
            expect(!GatewayConfiguration.isValidDialNumber(bad))
            rejects { _ = try config.callRequest(action: .dial, callID: nil, number: bad, requestID: requestID) }
        }
        rejects { _ = try config.callRequest(action: .answer, callID: "../dial", number: nil, requestID: requestID) }
        let pending = try decoder.decode(GatewayCallActionResult.self, from: Data(#"{"status":"pending","reason":"awaiting_clcc_confirmation"}"#.utf8))
        expect(pending.message.contains("等待"))
        let blocked = try decoder.decode(GatewayCallActionResult.self, from: Data(#"{"status":"blocked","reason":"nonvoice_session_present"}"#.utf8))
        expect(blocked.message.contains("数据会话"))
        print("Gateway behavior checks passed: \(checks)")
    }
}

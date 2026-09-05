import Foundation

// In-memory credential snapshot only. Never encode, log or persist this value.
struct GatewayConfiguration {
    static let defaultAddress = "http://192.168.1.97:17576"
    let baseURL: URL
    private let token: String

    init(address: String, token: String) throws {
        baseURL = try Self.normalizedURL(address)
        guard !token.isEmpty else { throw GatewayClientError.missingToken }
        guard token.utf8.count <= 4096,
              token.unicodeScalars.allSatisfy({ (33...126).contains($0.value) }) else {
            throw GatewayClientError.invalidToken
        }
        self.token = token
    }

    static func normalizedURL(_ address: String) throws -> URL {
        let input = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var parts = URLComponents(string: input),
              let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = parts.host?.lowercased(), !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/",
              parts.port == nil || (1...65535).contains(parts.port ?? 0) else {
            throw GatewayClientError.invalidAddress
        }
        // Do not send a bearer credential in cleartext to a public address.
        if scheme == "http" {
            let segments = host.split(separator: ".", omittingEmptySubsequences: false)
            let octets = segments.compactMap { UInt8($0) }
            let isPrivateIPv4 = segments.count == 4 && octets.count == 4 &&
                (octets[0] == 10 || (octets[0] == 192 && octets[1] == 168) ||
                 (octets[0] == 172 && (16...31).contains(octets[1])))
            guard isPrivateIPv4 || host.hasSuffix(".local") else { throw GatewayClientError.invalidAddress }
        }
        parts.scheme = scheme
        parts.host = host
        parts.path = ""
        if parts.port == (scheme == "https" ? 443 : 80) { parts.port = nil }
        guard let url = parts.url else { throw GatewayClientError.invalidAddress }
        return url
    }

    func request(path: String, webSocket: Bool = false) throws -> URLRequest {
        let paths = ["api/status", "api/calls", "api/messages"]
        guard (webSocket ? path == "ws" : paths.contains(path)) else { throw GatewayClientError.rejected }
        guard var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw GatewayClientError.invalidAddress
        }
        parts.path = "/" + path
        if webSocket { parts.scheme = baseURL.scheme == "https" ? "wss" : "ws" }
        guard let url = parts.url else { throw GatewayClientError.invalidAddress }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    func realtimeRequest() throws -> URLRequest {
        try request(path: "ws", webSocket: true)
    }

    func callRequest(action: GatewayCallAction, callID: String?, number: String?, requestID: UUID) throws -> URLRequest {
        let path: String
        var body: [String: Any] = [:]
        if action == .dial {
            guard let number, Self.isValidDialNumber(number) else {
                throw GatewayClientError.rejected
            }
            path = "/api/calls/dial"
            body = ["number": number, "confirmed": true]
        } else {
            guard let callID, callID.count == 32,
                  callID.unicodeScalars.allSatisfy({ (48...57).contains($0.value) || (65...70).contains($0.value) || (97...102).contains($0.value) }) else {
                throw GatewayClientError.rejected
            }
            path = "/api/calls/\(callID)/\(action.rawValue)"
        }
        var request = try self.request(path: "api/status")
        guard var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw GatewayClientError.invalidAddress
        }
        parts.path = path
        guard let url = parts.url else { throw GatewayClientError.invalidAddress }
        request.url = url
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue(requestID.uuidString, forHTTPHeaderField: "X-Request-ID")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func isValidDialNumber(_ value: String) -> Bool {
        let digits = value.hasPrefix("+") ? value.dropFirst() : value[...]
        return (5...15).contains(digits.count) && digits.unicodeScalars.allSatisfy { (48...57).contains($0.value) }
    }
}

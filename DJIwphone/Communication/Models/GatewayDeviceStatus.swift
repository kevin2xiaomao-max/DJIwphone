import Foundation

/// 网关返回的设备状态；保持与 Windows Gateway `/api/status` 的 JSON 契约独立。
struct GatewayDeviceStatus: Decodable, Equatable, Sendable {
    var online: Bool
    var simState: String?
    var operatorName: String?
    var signalStrength: String?
    var registration: String?
    var networkType: String?
    var updatedAt: Date?
    var simulated: Bool?
    var allowedCallActions: [String] = []

    enum CodingKeys: String, CodingKey { case online, port, sim, signal, simulated, operatorName = "operator", registration, networkType = "network_type", updatedAt = "updated_at", callState = "call_state", allowedCallActions = "allowed_call_actions" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        online = try c.decode(Bool.self, forKey: .online)
        allowedCallActions = try c.decodeIfPresent([String].self, forKey: .allowedCallActions) ?? []
        simState = try c.decodeIfPresent(String.self, forKey: .sim)
        operatorName = try c.decodeIfPresent(String.self, forKey: .operatorName)
        if let value = try? c.decode(String.self, forKey: .signal) { signalStrength = value }
        else if let value = try? c.decode(Int.self, forKey: .signal) { signalStrength = String(value) }
        else if let object = try? c.decode(SignalSnapshot.self, forKey: .signal) {
            signalStrength = object.csq.map(String.init) ?? object.dbm.map(String.init)
        } else { signalStrength = nil }
        if let value = try? c.decode(Int.self, forKey: .registration) { registration = String(value) }
        else { registration = try c.decodeIfPresent(String.self, forKey: .registration) }
        networkType = try c.decodeIfPresent(String.self, forKey: .networkType)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        simulated = try c.decodeIfPresent(Bool.self, forKey: .simulated)
    }

    private struct SignalSnapshot: Decodable {
        let csq: Int?
        let dbm: Int?
    }
}

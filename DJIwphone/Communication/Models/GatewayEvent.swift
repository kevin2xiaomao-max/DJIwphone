import Foundation

struct GatewayEvent: Decodable, Equatable, Sendable {
    let type: String
    let sequence: Int?
    let timestamp: Date?
    let data: GatewayEventData?

    enum CodingKeys: String, CodingKey { case type, sequence, timestamp, data }
}

struct GatewayEventData: Decodable, Equatable, Sendable {
    let callId: String?
    let direction: String?
    let state: String?
    let maskedNumber: String?
    let messageId: String?
    let deviceStatus: GatewayDeviceStatus?
    let detail: String?
    enum CodingKeys: String, CodingKey { case callId = "call_id", direction, state, maskedNumber = "masked_number", messageId = "message_id", deviceStatus = "device_status", detail, online, sim, signal, operatorName = "operator", registration, networkType = "network_type", updatedAt = "updated_at", callState = "call_state" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        callId = try c.decodeIfPresent(String.self, forKey: .callId)
        direction = try c.decodeIfPresent(String.self, forKey: .direction)
        state = try c.decodeIfPresent(String.self, forKey: .state)
        maskedNumber = try c.decodeIfPresent(String.self, forKey: .maskedNumber)
        messageId = try c.decodeIfPresent(String.self, forKey: .messageId)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
        if let nested = try c.decodeIfPresent(GatewayDeviceStatus.self, forKey: .deviceStatus) { deviceStatus = nested }
        else if (try c.decodeIfPresent(Bool.self, forKey: .online)) != nil { deviceStatus = try? GatewayDeviceStatus(from: decoder) }
        else { deviceStatus = nil }
    }
}

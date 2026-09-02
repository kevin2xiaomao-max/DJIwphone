import Foundation

struct GatewaySMSMessage: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let sender: String
    let body: String
    let receivedAt: Date
    let isVerificationCode: Bool
    let sentAt: String?

    enum CodingKeys: String, CodingKey {
        case id, sender, body
        case receivedAt = "received_at", sentAt = "sent_at", verificationCode = "verification_code"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        sender = try c.decode(String.self, forKey: .sender)
        body = try c.decode(String.self, forKey: .body)
        receivedAt = try c.decode(Date.self, forKey: .receivedAt)
        sentAt = try c.decodeIfPresent(String.self, forKey: .sentAt)
        isVerificationCode = !(try c.decodeIfPresent(String.self, forKey: .verificationCode) ?? "").isEmpty
    }
}

struct GatewayCall: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let direction: String
    var state: String
    let number: String?
    let timestamp: Date

    var isOngoing: Bool { ["incoming", "waiting", "dialing", "alerting", "active"].contains(state) }
    var directionTitle: String {
        switch direction {
        case "incoming": return "来电"
        case "outgoing": return "呼出"
        default: return "通话"
        }
    }
    var stateTitle: String {
        switch state {
        case "incoming": return "来电中"
        case "waiting": return "来电等待"
        case "dialing": return "正在呼叫"
        case "alerting": return "对方振铃"
        case "active": return "已接通"
        case "ended": return "已结束"
        case "busy": return "忙线"
        case "no_answer": return "未接通"
        case "failed": return "通话失败"
        default: return "状态未知"
        }
    }

    enum CodingKeys: String, CodingKey { case id, direction, state, number, maskedNumber = "masked_number", timestamp, startedAt = "started_at", endedAt = "ended_at", detail }

    init(id: String, direction: String, state: String, number: String?, timestamp: Date) {
        self.id = id; self.direction = direction; self.state = state; self.number = number; self.timestamp = timestamp
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        direction = try values.decode(String.self, forKey: .direction)
        state = try values.decode(String.self, forKey: .state)
        number = try values.decodeIfPresent(String.self, forKey: .number) ?? values.decodeIfPresent(String.self, forKey: .maskedNumber)
        timestamp = try values.decodeIfPresent(Date.self, forKey: .timestamp)
            ?? values.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date.distantPast
    }
}

struct GatewayListResponse<T: Decodable & Sendable>: Decodable, Sendable { let items: [T] }

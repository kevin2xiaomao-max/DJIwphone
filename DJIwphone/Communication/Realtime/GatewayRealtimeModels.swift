import Foundation

struct GatewayRealtimeEvent: Decodable, Equatable {
    let type: String
    let sequence: Int?
    let data: GatewayRealtimeCallData?

    struct GatewayRealtimeCallData: Decodable, Equatable {
        let callID: String?
        let state: String?
        let number: String?
        let maskedNumber: String?

        enum CodingKeys: String, CodingKey {
            case callID = "call_id"
            case state, number
            case maskedNumber = "masked_number"
        }
    }
}

extension GatewayRealtimeEvent {
    var callEvent: GatewayCallEvent? {
        guard type.hasPrefix("call."), let data, let id = data.callID,
              let state = data.state else { return nil }
        return GatewayCallEvent(type: type, callID: id, state: state,
                                number: data.number ?? data.maskedNumber)
    }
}

struct GatewayCallEvent: Equatable {
    let type: String
    let callID: String
    let state: String
    let number: String?
}

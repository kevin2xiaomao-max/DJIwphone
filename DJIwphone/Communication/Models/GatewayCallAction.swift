import Foundation

enum GatewayCallAction: String, Sendable {
    case dial, answer, reject, hangup

    var title: String {
        switch self {
        case .dial: return "拨号"
        case .answer: return "接听"
        case .reject: return "拒接"
        case .hangup: return "挂断"
        }
    }
}

struct GatewayCallActionResult: Decodable, Sendable {
    let status: String
    let reason: String?
    let state: String?
    let callID: String?
    enum CodingKeys: String, CodingKey {
        case status, reason, state
        case callID = "call_id"
    }

    var message: String {
        switch status {
        case "confirmed":
            switch state {
            case "active": return "已接通"
            case "ended": return "通话已结束"
            case "dialing": return "正在拨号"
            case "alerting": return "对方正在响铃"
            default: return "操作已确认"
            }
        case "pending": return "请求已受理，正在等待模块确认，请勿重复操作。"
        case "unconfirmed": return "暂时无法确认操作结果，请观察通话状态，不要重复操作。"
        default:
            switch reason {
            case "nonvoice_session_present", "chup_data_risk_confirmation_required":
                return "模块有数据会话，为避免误断网已拦截，请由对方挂断。"
            case "real_call_actions_disabled", "reject_not_enabled", "dial_disabled_incoming_only":
                return "Gateway 尚未开放此电话操作。"
            case "already_attempted_no_automatic_retry", "already_attempted_no_retry", "already_attempted_no_retry_pending":
                return "此操作已提交，请等待通话状态更新。"
            default: return "操作被拒绝，通话状态可能已变化。请刷新后检查。"
            }
        }
    }
}

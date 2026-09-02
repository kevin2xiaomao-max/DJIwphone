import Foundation

enum GatewayClientError: LocalizedError {
    case invalidAddress
    case missingToken
    case invalidToken
    case unauthorized
    case rejected
    case invalidResponse
    case disconnected
    case moduleOffline
    case simulatedGateway
    case keychain(Int32)

    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "请输入局域网 HTTP 地址或 HTTPS 地址，不要包含账号、路径或查询参数。"
        case .missingToken: return "请填写 Token；更换 Gateway 地址后需要重新填写。"
        case .invalidToken: return "Token 不能为空，也不能包含空格或换行。"
        case .unauthorized: return "Token 验证失败，请检查后重试。"
        case .rejected: return "Gateway 拒绝了请求，请检查允许的地址与访问策略。"
        case .invalidResponse: return "Gateway 返回格式不匹配，无法确认连接。"
        case .disconnected: return "连接已中断，请重新测试。"
        case .moduleOffline: return "Gateway 可访问，但 QDC507 当前离线。"
        case .simulatedGateway: return "连接的是模拟 Gateway，不能确认真实 QDC507 已连接。"
        case .keychain: return "无法读取或保存本机 Keychain，请解锁设备后重试。"
        }
    }

    // Do not expose response bodies, request URLs or arbitrary error descriptions.
    static func safeMessage(for error: Error) -> String {
        if let known = error as? GatewayClientError { return known.errorDescription ?? "连接失败" }
        if let network = error as? URLError {
            switch network.code {
            case .timedOut: return "连接超时，请确认 Windows Gateway 正在运行。"
            case .appTransportSecurityRequiresSecureConnection: return "iOS 阻止了 HTTP 连接，请先确认 App 的局域网 HTTP 策略。"
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost: return "无法访问 Gateway，请确认同一 Wi-Fi、地址和局域网权限。"
            case .cancelled: return "连接已取消。"
            default: break
            }
        }
        if error is DecodingError { return "Gateway 数据格式不匹配，请检查版本。" }
        return "连接失败，请检查地址、Token 和局域网权限。"
    }
}

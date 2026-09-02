import Foundation

@MainActor
protocol GatewayTokenStorage {
    func read(account: String) throws -> String?
    func save(_ token: String, account: String) throws
}

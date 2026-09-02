import Foundation
import Security

@MainActor
final class GatewayKeychain: GatewayTokenStorage {
    private let service = "com.xiaozhanggui.gateway.token.v1"

    private func query(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }

    func read(account: String) throws -> String? {
        var query = query(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let result = SecItemCopyMatching(query as CFDictionary, &item)
        if result == errSecItemNotFound { return nil }
        guard result == errSecSuccess, let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else { throw GatewayClientError.keychain(result) }
        return token
    }

    func save(_ token: String, account: String) throws {
        let query = query(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecItemNotFound {
            let insert = query.merging(attributes) { _, new in new }
            let result = SecItemAdd(insert as CFDictionary, nil)
            guard result == errSecSuccess else { throw GatewayClientError.keychain(result) }
        } else if update != errSecSuccess {
            throw GatewayClientError.keychain(update)
        }
    }
}

import Foundation
import Observation

@MainActor
@Observable
final class GatewaySettingsStore {
    private(set) var savedAddress: String
    private(set) var revision = UUID()
    private let defaults: UserDefaults
    private let tokenStorage: GatewayTokenStorage
    private let addressKey = "gateway.baseAddress.v1"

    init(defaults: UserDefaults = .standard, tokenStorage: GatewayTokenStorage? = nil) {
        self.defaults = defaults
        self.tokenStorage = tokenStorage ?? GatewayKeychain()
        savedAddress = defaults.string(forKey: addressKey) ?? GatewayConfiguration.defaultAddress
    }

    func configuration() throws -> GatewayConfiguration {
        try configuration(address: savedAddress, token: "")
    }

    func configuration(address: String, token: String) throws -> GatewayConfiguration {
        let endpoint = try GatewayConfiguration.normalizedURL(address)
        let resolvedToken: String
        if !token.isEmpty {
            resolvedToken = token
        } else {
            // A changed destination must never inherit the currently configured token.
            guard endpoint.absoluteString == (try GatewayConfiguration.normalizedURL(savedAddress)).absoluteString,
                  let stored = try tokenStorage.read(account: endpoint.absoluteString) else {
                throw GatewayClientError.missingToken
            }
            resolvedToken = stored
        }
        return try GatewayConfiguration(address: endpoint.absoluteString, token: resolvedToken)
    }

    func save(address: String, token: String) throws {
        let config = try configuration(address: address, token: token)
        // Commit address only after Keychain succeeds. Never persist token in defaults.
        if !token.isEmpty { try tokenStorage.save(token, account: config.baseURL.absoluteString) }
        defaults.set(config.baseURL.absoluteString, forKey: addressKey)
        savedAddress = config.baseURL.absoluteString
        revision = UUID()
    }
}

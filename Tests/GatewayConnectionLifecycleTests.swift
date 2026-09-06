import XCTest
@testable import DJIwphone

@MainActor
final class GatewayConnectionLifecycleTests: XCTestCase {
    func testFreshStoreStartsOffline() {
        let store = GatewayConnectionStore()
        XCTAssertEqual(store.connectionPhase, .offline)
        XCTAssertFalse(store.isConnected)
    }

    func testConnectionPhaseTransitionsToConnectingWhenRestartIsRequested() async {
        let store = GatewayConnectionStore()
        let settings = GatewaySettingsStore(defaults: UserDefaults(suiteName: "lifecycle-\(UUID().uuidString)")!, tokenStorage: InMemoryTokenStorage())
        store.restart(settings: settings)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(store.connectionPhase, .connecting)
        store.stop()
        XCTAssertEqual(store.connectionPhase, .offline)
    }
}

private final class InMemoryTokenStorage: GatewayTokenStorage {
    func read(account: String) throws -> String? { "test-token" }
    func save(_ token: String, account: String) throws {}
}

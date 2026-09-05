import CallKit
import Foundation

@MainActor
protocol DJIwphoneCallKitReporting: AnyObject {
    func reportIncoming(callID: String, handle: String)
    func reportConnected(callID: String)
    func reportEnded(callID: String)
}

@MainActor
final class DefaultDJIwphoneCallKit: NSObject, DJIwphoneCallKitReporting {
    private let provider: CXProvider
    private var uuids: [String: UUID] = [:]
    var onAction: ((String, GatewayCallAction) async -> Bool)?

    override init() {
        let configuration = CXProviderConfiguration(localizedName: DJIwphoneIdentity.displayName)
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        provider = CXProvider(configuration: configuration)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func reportIncoming(callID: String, handle: String) {
        let uuid = uuid(for: callID)
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        Task { [provider] in
            do { try await provider.reportNewIncomingCall(with: uuid, update: update) }
            catch { NSLog("DJIwphone CallKit incoming report failed: %@", String(describing: error)) }
        }
    }

    func reportConnected(callID: String) {
        provider.reportOutgoingCall(with: uuid(for: callID), connectedAt: Date())
    }

    func reportEnded(callID: String) {
        provider.reportCall(with: uuid(for: callID), endedAt: Date(), reason: .remoteEnded)
        uuids.removeValue(forKey: callID)
    }

    private func uuid(for callID: String) -> UUID {
        if let existing = uuids[callID] { return existing }
        let uuid = UUID(uuidString: callID) ?? UUID()
        uuids[callID] = uuid
        return uuid
    }
}

extension DefaultDJIwphoneCallKit: CXProviderDelegate {
    nonisolated func providerDidReset(_ provider: CXProvider) {}
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        perform(action, gatewayAction: .answer)
    }
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        perform(action, gatewayAction: .hangup)
    }
    private func perform(_ action: CXCallAction, gatewayAction: GatewayCallAction) {
        let callID = uuids.first(where: { $0.value == action.uuid })?.key
        guard let callID, let onAction else { action.fail(); return }
        Task { await onAction(callID, gatewayAction) ? action.fulfill() : action.fail() }
    }
}

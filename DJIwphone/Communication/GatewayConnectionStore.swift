import Foundation
import Observation

@MainActor
@Observable
final class GatewayConnectionStore {
    enum ConnectionPhase: Equatable { case offline, connecting, online }
    private(set) var connectionPhase: ConnectionPhase = .offline
    private(set) var status: GatewayDeviceStatus?
    private(set) var messages: [GatewaySMSMessage] = []
    private(set) var calls: [GatewayCall] = []
    let audioSession = GatewayCallAudioSession()
    private let callCoordinator: CallCoordinator
    private let callKit: DefaultDJIwphoneCallKit
    private(set) var isConnected = false
    private(set) var lastError: String?
    private(set) var messagesError: String?
    private var client: GatewayClient?
    private var generation = UUID()
    private var eventRevision = 0
    private var isRefreshing = false
    private var messagesRefreshRequested = false
    private(set) var callActionInFlight = false
    private(set) var callActionMessage: String?
    private var pendingAction: (action: GatewayCallAction, id: String?)?
    private var attemptedActions: Set<String> = []
    private var refreshTask: Task<Void, Never>?

    init() {
        let callKit = DefaultDJIwphoneCallKit()
        self.callKit = callKit
        self.callCoordinator = CallCoordinator(callKit: callKit)
        callKit.onAction = { [weak self] callID, action in
            guard let self else { return false }
            guard let call = self.calls.first(where: { $0.id == callID }) else { return false }
            await self.performCallAction(action, call: call)
            return true
        }
    }

    var callControlsBusy: Bool { callActionInFlight || pendingAction != nil }

    func canPerform(_ action: GatewayCallAction, call: GatewayCall? = nil) -> Bool {
        guard isConnected, status?.online == true, status?.simulated == false,
              status?.allowedCallActions.contains(action.rawValue) == true,
              !callControlsBusy else { return false }
        if action == .dial { return currentCall == nil }
        guard let call, currentCall?.id == call.id,
              !attemptedActions.contains(call.id + ":" + action.rawValue) else { return false }
        switch action {
        case .answer, .reject: return call.direction == "incoming" && call.state == "incoming"
        case .hangup: return ["active", "dialing", "alerting"].contains(call.state)
        case .dial: return false
        }
    }

    func performCallAction(_ action: GatewayCallAction, call: GatewayCall? = nil, number: String? = nil) async {
        guard canPerform(action, call: call), let client else { return }
        let current = generation
        let key = (call?.id ?? "dial") + ":" + action.rawValue
        callActionInFlight = true
        pendingAction = (action, call?.id)
        attemptedActions.insert(key)
        callActionMessage = "正在\(action.title)…"
        defer { callActionInFlight = false }
        do {
            let result = try await client.performCallAction(action, callID: call?.id, number: number, requestID: UUID())
            guard generation == current else { return }
            callActionMessage = result.message
            if result.status == "blocked" {
                attemptedActions.remove(key)
                pendingAction = nil
            } else if result.status == "confirmed" {
                pendingAction = nil
            }
            if isRefreshing { messagesRefreshRequested = true }
            else { await refreshReadOnlyState() }
            resolvePendingAction()
        } catch {
            guard generation == current else { return }
            callActionMessage = "操作结果未确认：" + GatewayClientError.safeMessage(for: error) + " 请勿重复操作，等待状态同步。"
            // Keep the uncertainty gate closed; a network failure is not proof of no action.
            resolvePendingAction()
        }
    }

    private func resolvePendingAction() {
        guard let pending = pendingAction else { return }
        let call = pending.id.flatMap { id in calls.first(where: { $0.id == id }) }
        if pending.action == .dial {
            if let outgoing = currentCall, outgoing.direction == "outgoing" {
                pendingAction = nil
                callActionMessage = outgoing.stateTitle
            }
        } else if let call {
            if !call.isOngoing || (pending.action == .answer && call.state == "active") {
                pendingAction = nil
                callActionMessage = call.stateTitle
            }
        }
    }

    var deviceConnectionTitle: String {
        guard isConnected else { return "QDC507 未连接" }
        if status?.simulated == true { return "模拟 Gateway" }
        return status?.online == true && status?.simulated == false ? "QDC507 已连接" : "QDC507 未连接"
    }
    var currentCall: GatewayCall? { calls.first(where: { $0.isOngoing }) }

    func startReadOnlyRefresh(settings: GatewaySettingsStore) async {
        refreshTask = nil
        stop()
        connectionPhase = .connecting
        let current = generation
        do {
            let connection = try URLSessionGatewayClient(settings: settings)
            client = connection
            connection.onEvent = { [weak self] event in
                guard let self, self.generation == current else { return }
                self.apply(event)
            }
            connection.onDisconnect = { [weak self] in
                guard let self, self.generation == current else { return }
                self.isConnected = false
                self.connectionPhase = .offline
                self.lastError = "实时连接已中断，正在等待重连。"
            }
        } catch {
            connectionPhase = .offline
            lastError = GatewayClientError.safeMessage(for: error)
            return
        }
        defer { if generation == current { stop() } }
        while !Task.isCancelled && generation == current {
            await refreshReadOnlyState()
            do { try await Task.sleep(for: .seconds(10)) }
            catch { return }
        }
    }

    func restart(settings: GatewaySettingsStore) {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.startReadOnlyRefresh(settings: settings)
        }
    }

    func stop() {
        generation = UUID()
        client?.onEvent = nil
        client?.onDisconnect = nil
        client?.disconnect()
        client = nil
        isConnected = false
        connectionPhase = .offline
        isRefreshing = false
        status = nil
        calls = []
        messages = []
        lastError = nil
        messagesError = nil
        messagesRefreshRequested = false
    }

    func refreshReadOnlyState() async {
        guard let client, !isRefreshing else { return }
        isRefreshing = true
        let current = generation
        defer {
            if generation == current {
                isRefreshing = false
                if messagesRefreshRequested {
                    messagesRefreshRequested = false
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == current else { return }
                        await self.refreshReadOnlyState()
                    }
                }
            }
        }
        do {
            let snapshot = try await client.fetchStatus()
            try Task.checkCancellation()
            guard generation == current else { return }
            status = snapshot
            try await client.connectEvents()
            guard generation == current else { return }
            isConnected = true
            connectionPhase = .online
            lastError = nil
            let beforeCalls = eventRevision
            let newCalls = try await client.fetchCalls()
            guard generation == current else { return }
            if beforeCalls == eventRevision { calls = newCalls; resolvePendingAction() }
            do {
                let newMessages = try await client.fetchMessages()
                guard generation == current else { return }
                messages = newMessages
                messagesError = nil
            } catch {
                guard generation == current else { return }
                messagesError = "短信列表未更新：" + GatewayClientError.safeMessage(for: error)
            }
        } catch {
            guard generation == current, !Task.isCancelled else { return }
            isConnected = false
            connectionPhase = .offline
            lastError = GatewayClientError.safeMessage(for: error)
            client.disconnect()
        }
    }

    func sendSMS(number: String, body: String) async -> Result<Void, Error> {
        guard let client else { return .failure(GatewayClientError.disconnected) }
        do { try await client.sendSMS(number: number, body: body, requestID: UUID()); await refreshReadOnlyState(); return .success(()) }
        catch { return .failure(error) }
    }

    private func apply(_ event: GatewayEvent) {
        if let data = event.data, let callID = data.callId, let state = data.state {
            callCoordinator.apply(GatewayCallEvent(type: event.type, callID: callID,
                                                   state: state, number: data.maskedNumber))
        }
        switch event.type {
        case "sms.received":
            if isRefreshing { messagesRefreshRequested = true }
            else {
                let current = generation
                Task { @MainActor [weak self] in
                    guard let self, self.generation == current else { return }
                    await self.refreshReadOnlyState()
                }
            }
        case "device.status":
            if let value = event.data?.deviceStatus {
                status = value
                isConnected = true
            }
        case "call.ringing", "call.state", "call.ended":
            guard let data = event.data, let id = data.callId else { return }
            if let audioEvent = GatewayAudioEventType(rawValue: event.type) {
                audioSession.apply(callID: id, event: audioEvent, state: data.state)
            } else if data.state == "active" {
                audioSession.apply(callID: id, event: .answered, state: data.state)
            }
            eventRevision += 1
            let fallback = event.type == "call.ended" ? "ended" : "incoming"
            if let index = calls.firstIndex(where: { $0.id == id }) {
                let previous = calls[index]
                calls[index] = GatewayCall(id: id, direction: data.direction ?? previous.direction,
                    state: data.state ?? previous.state, number: data.maskedNumber ?? previous.number,
                    timestamp: previous.timestamp)
            } else {
                calls.insert(GatewayCall(id: id, direction: data.direction ?? "unknown",
                    state: data.state ?? fallback, number: data.maskedNumber,
                    timestamp: event.timestamp ?? Date()), at: 0)
            }
            resolvePendingAction()
            if data.state == "ended" { callActionMessage = "通话已结束" }
            if isRefreshing { messagesRefreshRequested = true }
            else {
                let current = generation
                Task { @MainActor [weak self] in
                    guard let self, self.generation == current else { return }
                    await self.refreshReadOnlyState()
                }
            }
        default: break
        }
    }
}

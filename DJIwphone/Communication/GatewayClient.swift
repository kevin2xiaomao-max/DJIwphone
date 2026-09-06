import Foundation

@MainActor
protocol GatewayClient: AnyObject {
    var baseURL: URL { get }
    func fetchStatus() async throws -> GatewayDeviceStatus
    func fetchMessages() async throws -> [GatewaySMSMessage]
    func fetchCalls() async throws -> [GatewayCall]
    func performCallAction(_ action: GatewayCallAction, callID: String?, number: String?, requestID: UUID) async throws -> GatewayCallActionResult
    func sendSMS(number: String, body: String, requestID: UUID) async throws
    func connectEvents() async throws
    func disconnect()
    var onEvent: ((GatewayEvent) -> Void)? { get set }
    var onDisconnect: (() -> Void)? { get set }
}

@MainActor
final class URLSessionGatewayClient: GatewayClient {
    var baseURL: URL { configuration.baseURL }
    var onEvent: ((GatewayEvent) -> Void)?
    var onDisconnect: (() -> Void)?
    private let configuration: GatewayConfiguration
    private let session: URLSession
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var eventsReady = false
    private var initialStatus: GatewayDeviceStatus?
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    init(configuration: GatewayConfiguration) {
        self.configuration = configuration
        let settings = URLSessionConfiguration.ephemeral
        settings.httpCookieStorage = nil
        settings.httpShouldSetCookies = false
        settings.urlCache = nil
        settings.requestCachePolicy = .reloadIgnoringLocalCacheData
        settings.timeoutIntervalForRequest = 10
        settings.timeoutIntervalForResource = 40
        session = URLSession(configuration: settings, delegate: GatewayRedirectBlocker(), delegateQueue: nil)
    }

    convenience init(settings: GatewaySettingsStore) throws {
        self.init(configuration: try settings.configuration())
    }

    deinit { session.invalidateAndCancel() }

    func fetchStatus() async throws -> GatewayDeviceStatus { try await get("api/status") }
    func fetchMessages() async throws -> [GatewaySMSMessage] { try await getList("api/messages") }
    func fetchCalls() async throws -> [GatewayCall] { try await getList("api/calls") }

    func performCallAction(_ action: GatewayCallAction, callID: String?, number: String?, requestID: UUID) async throws -> GatewayCallActionResult {
        let request = try configuration.callRequest(action: action, callID: callID, number: number, requestID: requestID)
        // Exactly one POST attempt; never retry an uncertain real action.
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GatewayClientError.invalidResponse }
        if http.statusCode == 401 { throw GatewayClientError.unauthorized }
        guard [200, 202, 400, 403, 409].contains(http.statusCode) else { throw GatewayClientError.invalidResponse }
        let result = try decoder.decode(GatewayCallActionResult.self, from: data)
        let expected = ["confirmed": 200, "pending": 202, "blocked": 403, "unconfirmed": 409]
        guard expected[result.status] == http.statusCode || (http.statusCode == 400 && result.status == "blocked") else {
            throw GatewayClientError.invalidResponse
        }
        return result
    }
    func sendSMS(number: String, body: String, requestID: UUID) async throws {
        let (data, response) = try await session.data(for: configuration.smsRequest(number: number, body: body, requestID: requestID))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw GatewayClientError.rejected }
        struct Response: Decodable { let status: String }
        let result = try decoder.decode(Response.self, from: data)
        guard result.status == "sent" else { throw GatewayClientError.rejected }
    }

    // Requires HTTP data AND an authenticated WebSocket device.status frame.
    func validateConnection() async throws {
        defer { disconnect() }
        let status = try await fetchStatus()
        try await connectEvents()
        guard let first = initialStatus else { throw GatewayClientError.invalidResponse }
        guard status.simulated == false, first.simulated == false else { throw GatewayClientError.simulatedGateway }
        guard status.online, first.online else { throw GatewayClientError.moduleOffline }
    }

    func connectEvents() async throws {
        if eventsReady { return }
        guard socket == nil else { throw GatewayClientError.disconnected }
        let candidate = session.webSocketTask(with: try configuration.request(path: "ws", webSocket: true))
        candidate.maximumMessageSize = 1_048_576
        socket = candidate
        candidate.resume()
        var didTimeout = false
        let timeout = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(10))
                didTimeout = true
                candidate.cancel(with: .goingAway, reason: nil)
            } catch { }
        }
        defer { timeout.cancel() }
        do {
            let message = try await withTaskCancellationHandler {
                try await candidate.receive()
            } onCancel: {
                candidate.cancel(with: .goingAway, reason: nil)
            }
            try Task.checkCancellation()
            guard socket === candidate else { throw GatewayClientError.disconnected }
            let event = try decode(message)
            guard event.type == "device.status", let status = event.data?.deviceStatus else {
                throw GatewayClientError.invalidResponse
            }
            initialStatus = status
            eventsReady = true
            onEvent?(event)
            receiveTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do {
                        let message = try await candidate.receive()
                        guard let self, self.socket === candidate, !Task.isCancelled else { return }
                        self.onEvent?(try self.decode(message))
                    } catch {
                        guard let self, self.socket === candidate else { return }
                        self.disconnect()
                        self.onDisconnect?()
                        return
                    }
                }
            }
        } catch {
            if socket === candidate { disconnect() }
            if didTimeout { throw URLError(.timedOut) }
            throw error
        }
    }

    func disconnect() {
        eventsReady = false
        initialStatus = nil
        let previous = socket
        socket = nil
        receiveTask?.cancel()
        receiveTask = nil
        previous?.cancel(with: .normalClosure, reason: nil)
    }

    private func decode(_ message: URLSessionWebSocketTask.Message) throws -> GatewayEvent {
        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let bytes): data = bytes
        @unknown default: throw GatewayClientError.invalidResponse
        }
        return try decoder.decode(GatewayEvent.self, from: data)
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, response) = try await session.data(for: configuration.request(path: path))
        guard let http = response as? HTTPURLResponse else { throw GatewayClientError.invalidResponse }
        switch http.statusCode {
        case 200..<300: break
        case 401: throw GatewayClientError.unauthorized
        case 403: throw GatewayClientError.rejected
        default: throw GatewayClientError.invalidResponse
        }
        return try decoder.decode(T.self, from: data)
    }

    private func getList<T: Decodable & Sendable>(_ path: String) async throws -> [T] {
        let response: GatewayListResponse<T> = try await get(path)
        return response.items
    }
}

import Foundation

@MainActor
protocol GatewayRealtimeSignaling: AnyObject {
    var onEvent: ((GatewayRealtimeEvent) -> Void)? { get set }
    var onDisconnect: (() -> Void)? { get set }
    func connect() throws
    func disconnect()
}

@MainActor
final class URLSessionGatewayRealtimeSignaling: NSObject, GatewayRealtimeSignaling, URLSessionWebSocketDelegate {
    var onEvent: ((GatewayRealtimeEvent) -> Void)?
    var onDisconnect: (() -> Void)?

    private let request: URLRequest
    private var socket: URLSessionWebSocketTask?
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)

    init(request: URLRequest) { self.request = request }

    func connect() throws {
        guard socket == nil else { return }
        let task = session.webSocketTask(with: request)
        socket = task
        task.resume()
        receive(on: task)
    }

    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    private func receive(on task: URLSessionWebSocketTask) {
        task.receive { [weak self, weak task] result in
            Task { @MainActor [weak self, weak task] in
                guard let self, let task, self.socket === task else { return }
                switch result {
                case .success(.string(let text)):
                    if let data = text.data(using: .utf8),
                       let event = try? JSONDecoder().decode(GatewayRealtimeEvent.self, from: data) {
                        self.onEvent?(event)
                    }
                    self.receive(on: task)
                case .success(.data(let data)):
                    if let event = try? JSONDecoder().decode(GatewayRealtimeEvent.self, from: data) {
                        self.onEvent?(event)
                    }
                    self.receive(on: task)
                case .failure:
                    self.socket = nil
                    self.onDisconnect?()
                @unknown default:
                    self.socket = nil
                    self.onDisconnect?()
                }
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                                didOpenWithProtocol protocol: String?) {}

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard error != nil else { return }
        Task { @MainActor [weak self] in
            guard let self, self.socket != nil else { return }
            self.socket = nil
            self.onDisconnect?()
        }
    }
}

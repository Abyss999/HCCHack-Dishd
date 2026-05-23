import Foundation

@MainActor
final class WebSocketService: NSObject, ObservableObject {
    var onMemberJoined:  ((MemberJoinedPayload) -> Void)?
    var onSwipeProgress: ((SwipeProgressPayload) -> Void)?
    var onInstantMatch:  ((InstantMatchPayload) -> Void)?
    var onPhaseChange:   ((PhaseChangePayload) -> Void)?
    var onTop3Ready:     ((Top3ReadyPayload) -> Void)?

    @Published private(set) var isConnected = false

    private var task: URLSessionWebSocketTask?
    private var reconnectAttempts = 0
    private var sessionId: UUID?
    private var token: String?
    private var reconnectTask: Task<Void, Never>?

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy  = .convertFromSnakeCase
        return d
    }

    func connect(sessionId: UUID, token: String) {
        self.sessionId = sessionId
        self.token = token
        reconnectAttempts = 0
        openSocket()
    }

    func disconnect() {
        reconnectTask?.cancel()
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        isConnected = false
    }

    private func openSocket() {
        guard let sessionId, let token else { return }
        var comps = URLComponents(url: Config.wsBaseURL.appendingPathComponent("ws/sessions/\(sessionId)"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "token", value: token)]
        let cfg = URLSessionConfiguration.default
        let urlSession = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
        task = urlSession.webSocketTask(with: comps.url!)
        task?.resume()
        receive()
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case .success(let msg):
                    self.handle(msg)
                    self.receive()
                case .failure:
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else { return }
        let dec = WebSocketService.decoder
        guard let envelope = try? dec.decode(WSEnvelope.self, from: data),
              let payloadData = try? envelope.payload.toData()
        else { return }

        switch envelope.type {
        case .memberJoined:
            if let p = try? dec.decode(MemberJoinedPayload.self,  from: payloadData) { onMemberJoined?(p) }
        case .swipeProgress:
            if let p = try? dec.decode(SwipeProgressPayload.self, from: payloadData) { onSwipeProgress?(p) }
        case .instantMatch:
            if let p = try? dec.decode(InstantMatchPayload.self,  from: payloadData) { onInstantMatch?(p) }
        case .phaseChange:
            if let p = try? dec.decode(PhaseChangePayload.self,   from: payloadData) { onPhaseChange?(p) }
        case .top3Ready:
            if let p = try? dec.decode(Top3ReadyPayload.self,     from: payloadData) { onTop3Ready?(p) }
        }
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < 5 else { return }
        let delay = pow(2.0, Double(reconnectAttempts))
        reconnectAttempts += 1
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run { self.openSocket() }
        }
    }
}

extension WebSocketService: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor in
            self.isConnected = true
            self.reconnectAttempts = 0
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @MainActor in
            self.isConnected = false
        }
    }
}

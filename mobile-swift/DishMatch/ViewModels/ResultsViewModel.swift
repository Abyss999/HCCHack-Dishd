import Foundation

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var results: [SessionResult] = []
    @Published var isLoading = false

    let sessionId: UUID
    let sessionVM: SessionViewModel
    let ws = WebSocketService()

    init(sessionId: UUID, sessionVM: SessionViewModel) {
        self.sessionId = sessionId
        self.sessionVM = sessionVM
        setupWS()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        try? await sessionVM.fetchResults(sessionId: sessionId)
        results = sessionVM.results
    }

    private func setupWS() {
        guard let token = sessionVM.token else { return }
        ws.connect(sessionId: sessionId, token: token)
        ws.onTop3Ready = { [weak self] p in
            self?.results = p.results
        }
    }
}

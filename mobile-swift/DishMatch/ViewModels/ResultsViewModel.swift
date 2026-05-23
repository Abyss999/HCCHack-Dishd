import Foundation

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var results: [SessionResult] = []
    @Published var isLoading = false
    @Published var vibePick: VibePick?
    @Published var isLoadingVibe = false

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
        await loadVibePick()
    }

    func loadVibePick() async {
        guard vibePick == nil else { return }
        isLoadingVibe = true
        defer { isLoadingVibe = false }
        // Retry once: results may still be empty on the first call for matched
        // sessions where the swipe count is low. Give the backend a moment.
        if results.isEmpty {
            try? await Task.sleep(for: .milliseconds(800))
            try? await sessionVM.fetchResults(sessionId: sessionId)
            results = sessionVM.results
        }
        guard !results.isEmpty else { return }
        vibePick = try? await sessionVM.fetchVibePick(sessionId: sessionId)
    }

    private func setupWS() {
        guard let token = sessionVM.token else { return }
        ws.connect(sessionId: sessionId, token: token)
        ws.onTop3Ready = { [weak self] p in
            self?.results = p.results
            Task { await self?.loadVibePick() }
        }
    }
}

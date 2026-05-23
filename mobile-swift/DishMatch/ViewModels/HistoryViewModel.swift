import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let sessionVM: SessionViewModel

    init(sessionVM: SessionViewModel) {
        self.sessionVM = sessionVM
    }

    var currentUserId: UUID? { AuthStore.shared.user?.id }

    func isHost(of session: Session) -> Bool {
        guard let uid = currentUserId else { return false }
        return session.hostUserId == uid
    }

    func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            sessions = try await sessionVM.fetchUserSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leave(_ session: Session) async {
        do {
            try await sessionVM.leaveSession(session.id)
            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ session: Session) async {
        do {
            try await sessionVM.deleteSession(session.id)
            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes all given sessions — delete-as-host where possible, otherwise leave.
    func clearAll(_ targets: [Session]) async {
        for session in targets {
            do {
                if isHost(of: session) {
                    try await sessionVM.deleteSession(session.id)
                } else {
                    try await sessionVM.leaveSession(session.id)
                }
                sessions.removeAll { $0.id == session.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

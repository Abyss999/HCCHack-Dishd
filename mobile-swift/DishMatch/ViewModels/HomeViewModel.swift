import Foundation
import CoreLocation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var createdSession: Session?
    @Published var joinedSession: Session?
    @Published var pastSessions: [Session] = []

    private let sessionVM: SessionViewModel

    init(sessionVM: SessionViewModel) {
        self.sessionVM = sessionVM
    }

    func fetchPastSessions() async {
        do {
            pastSessions = try await sessionVM.fetchUserSessions()
        } catch {
            // non-critical — silently fail, history stays empty
        }
    }

    func createSession(
        lat: Double = 0, lng: Double = 0,
        label: String? = nil,
        soloMode: Bool = false,
        cuisineOverrides: [String]? = nil,
        radiusKmOverride: Double? = nil,
        budgetOverrides: [String]? = nil,
        swipeCeilingOverride: Int? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            createdSession = try await sessionVM.createSession(
                lat: lat, lng: lng, soloMode: soloMode, locationLabel: label,
                cuisineOverrides: cuisineOverrides,
                radiusKmOverride: radiusKmOverride,
                budgetOverrides: budgetOverrides,
                swipeCeilingOverride: swipeCeilingOverride
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinSession(code: String) async {
        guard code.count == 4 else {
            errorMessage = "Please enter a 4-character code."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            joinedSession = try await sessionVM.joinSession(code: code)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

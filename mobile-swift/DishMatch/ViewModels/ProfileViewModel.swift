import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var dietaryRestrictions: [String] = []
    @Published var cuisinePreferences: [String] = []
    @Published var budgetRanges: [String] = []   // multi-select; saved as max budget
    @Published var maxDistanceKm = 10.0
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var saveSuccess = false

    private let api: APIClient
    private let auth: AuthStore

    private static let budgetOrder = ["$": 1, "$$": 2, "$$$": 3, "$$$$": 4]

    init(api: APIClient = .shared, auth: AuthStore = .shared) {
        self.api = api
        self.auth = auth
        if let prefs = auth.user?.preferences {
            dietaryRestrictions = prefs.dietaryRestrictions
            cuisinePreferences  = prefs.cuisinePreferences
            budgetRanges        = prefs.budgetRange.map { [$0] } ?? []
            maxDistanceKm       = prefs.maxDistanceKm
        }
    }

    var maxBudget: String? {
        budgetRanges.max(by: { (Self.budgetOrder[$0] ?? 0) < (Self.budgetOrder[$1] ?? 0) })
    }

    func savePreferences() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        let prefs = UserPreferences(
            dietaryRestrictions: dietaryRestrictions,
            cuisinePreferences:  cuisinePreferences,
            budgetRange:         maxBudget,
            maxDistanceKm:       maxDistanceKm
        )
        do {
            let updated: User = try await api.put("/users/me/preferences",
                                                  body: prefs,
                                                  token: auth.accessToken)
            auth.updateUser(updated)  // so CreateSessionSheet prefills from fresh prefs
            saveSuccess = true
        } catch {
            saveError = error.localizedDescription
        }
    }

    func toggle(_ item: String, in list: inout [String]) {
        if list.contains(item) {
            list.removeAll { $0 == item }
        } else {
            list.append(item)
        }
    }
}

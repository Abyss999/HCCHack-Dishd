import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var dietaryRestrictions: [String] = []
    @Published var cuisinePreferences: [String] = []
    @Published var budgetRange = "$$"
    @Published var maxDistanceKm = 10.0
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var saveSuccess = false

    private let api: APIClient
    private let auth: AuthStore

    init(api: APIClient = .shared, auth: AuthStore = .shared) {
        self.api = api
        self.auth = auth
        if let prefs = auth.user?.preferences {
            dietaryRestrictions = prefs.dietaryRestrictions
            cuisinePreferences  = prefs.cuisinePreferences
            budgetRange         = prefs.budgetRange ?? "$$"
            maxDistanceKm       = prefs.maxDistanceKm
        }
    }

    func savePreferences() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        let prefs = UserPreferences(
            dietaryRestrictions: dietaryRestrictions,
            cuisinePreferences:  cuisinePreferences,
            budgetRange:         budgetRange,
            maxDistanceKm:       maxDistanceKm
        )
        do {
            let _: User = try await api.put("/users/me/preferences",
                                             body: prefs,
                                             token: auth.accessToken)
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

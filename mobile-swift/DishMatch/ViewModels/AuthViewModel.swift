import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let auth: AuthStore

    init(auth: AuthStore = .shared) {
        self.auth = auth
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await auth.login(email: email.lowercased(), password: password)
        } catch APIError.unauthorized {
            errorMessage = "Invalid email or password."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signup(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await auth.signup(email: email.lowercased(), password: password, name: name)
        } catch APIError.unauthorized {
            errorMessage = "Invalid email or password."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

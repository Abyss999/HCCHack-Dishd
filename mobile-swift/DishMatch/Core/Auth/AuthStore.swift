import Foundation

@MainActor
final class AuthStore: ObservableObject {
    static let shared = AuthStore()

    @Published private(set) var user: User?
    @Published private(set) var isLoading = true
    @Published private(set) var isAuthenticated = false

    private(set) var accessToken: String?
    private let api: APIClient

    private init(api: APIClient = .shared) {
        self.api = api
    }

    func restoreSession() async {
        defer { isLoading = false }
        guard
            let stored = try? KeychainService.get("auth_tokens"),
            let data = stored.data(using: .utf8),
            let tokens = try? JSONDecoder().decode(AuthTokens.self, from: data)
        else { return }

        accessToken = tokens.accessToken
        do {
            user = try await api.get("/users/me", token: tokens.accessToken)
            isAuthenticated = true
        } catch APIError.unauthorized {
            await refreshAccessToken(using: tokens.refreshToken)
        } catch {
            clearTokens()
        }
    }

    func login(email: String, password: String) async throws {
        let tokens: AuthTokens = try await api.post(
            "/auth/login",
            body: ["email": email, "password": password]
        )
        try persistTokens(tokens)
        user = try await api.get("/users/me", token: tokens.accessToken)
        isAuthenticated = true
    }

    func signup(email: String, password: String, name: String) async throws {
        let tokens: AuthTokens = try await api.post(
            "/auth/signup",
            body: ["email": email, "password": password, "name": name]
        )
        try persistTokens(tokens)
        user = try await api.get("/users/me", token: tokens.accessToken)
        isAuthenticated = true
    }

    func logout() {
        clearTokens()
        isAuthenticated = false
    }

    /// Replace the cached `user` after a server-side mutation (e.g. PUT /users/me/preferences)
    /// so other views like CreateSessionSheet see fresh prefs without re-fetching /users/me.
    func updateUser(_ user: User) {
        self.user = user
    }

    @discardableResult
    func refreshAccessToken(using refreshToken: String) async -> Bool {
        guard let tokens: AuthTokens = try? await api.post(
            "/auth/refresh",
            body: ["refresh_token": refreshToken]
        ) else {
            clearTokens()
            return false
        }
        try? persistTokens(tokens)
        return true
    }

    private func persistTokens(_ tokens: AuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        guard let str = String(data: data, encoding: .utf8) else { return }
        try KeychainService.set(str, forKey: "auth_tokens")
        accessToken = tokens.accessToken
    }

    private func clearTokens() {
        KeychainService.delete("auth_tokens")
        accessToken = nil
        user = nil
    }
}

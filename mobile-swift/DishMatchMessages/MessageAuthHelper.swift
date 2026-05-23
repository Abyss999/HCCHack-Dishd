import Foundation

struct MessageAuthHelper {
    private let tokenKey = "auth_tokens"

    func loadToken() -> String? {
        guard let stored = try? KeychainService.get(tokenKey, shared: true),
              let data = stored.data(using: .utf8),
              let tokens = try? JSONDecoder().decode(AuthTokens.self, from: data)
        else { return nil }
        return tokens.accessToken
    }
}

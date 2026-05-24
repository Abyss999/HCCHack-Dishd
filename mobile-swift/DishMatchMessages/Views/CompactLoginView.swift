import AuthenticationServices
import SwiftUI

struct CompactLoginView: View {
    var onLoginSuccess: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "fork.knife.circle.fill")
                    .foregroundColor(Color(hex: "#d97757"))
                    .font(.system(size: 22))
                Text("Dishd")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()

            Text("Sign in to start voting on restaurants with friends.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
            }

            SignInWithAppleButton(.signIn,
                onRequest: { $0.requestedScopes = [.fullName, .email] },
                onCompletion: { result in
                    if case .success(let auth) = result,
                       let cred = auth.credential as? ASAuthorizationAppleIDCredential {
                        Task { await handleCredential(cred) }
                    }
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 44)
            .cornerRadius(10)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleCredential(_ cred: ASAuthorizationAppleIDCredential) async {
        errorMessage = nil
        guard let tokenData = cred.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            errorMessage = "Failed to read Apple identity token"
            return
        }
        struct Body: Encodable { let identityToken: String; let fullName: String? }
        let name = [cred.fullName?.givenName, cred.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        do {
            let tokens: AuthTokens = try await APIClient.shared.post(
                "/auth/apple",
                body: Body(identityToken: identityToken, fullName: name.isEmpty ? nil : name)
            )
            let encoded = try JSONEncoder().encode(tokens)
            guard let str = String(data: encoded, encoding: .utf8) else { return }
            try KeychainService.set(str, forKey: "auth_tokens", shared: true)
            onLoginSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


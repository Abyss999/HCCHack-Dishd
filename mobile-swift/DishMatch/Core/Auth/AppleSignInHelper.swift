import AuthenticationServices

final class AppleSignInHelper: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private weak var anchor: ASPresentationAnchor?

    func signIn(from anchor: ASPresentationAnchor) async throws -> ASAuthorizationAppleIDCredential {
        self.anchor = anchor
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let req = ASAuthorizationAppleIDProvider().createRequest()
            req.requestedScopes = [.fullName, .email]
            let ctrl = ASAuthorizationController(authorizationRequests: [req])
            ctrl.delegate = self
            ctrl.presentationContextProvider = self
            ctrl.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        continuation?.resume(returning: cred)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor!
    }
}

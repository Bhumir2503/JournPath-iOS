//
//  AppleAuthService.swift
//  MyJourney
//

import AuthenticationServices
import FirebaseAuth

class AppleAuthService: NSObject {
    private var currentNonce: String?
    private var completion: CheckedContinuation<(AuthCredential, String?), Error>?

    @MainActor
    func getCredential() async throws(AuthError) -> (AuthCredential, String?) {
        let nonce = AuthCryptoUtils.generateNonce()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email]
        request.nonce = AuthCryptoUtils.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        do {
            return try await withCheckedThrowingContinuation { continuation in
                self.completion = continuation
                controller.performRequests()
            }
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    @MainActor
    func startSignInFlow() async throws(AuthError) {
        do {
            let (credential, _) = try await getCredential()
            try await Auth.auth().signIn(with: credential)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    /// Resolves the pending continuation and clears per-flow state (nonce + completion)
    /// so nothing stale is left around for the next sign-in attempt.
    private func finish(_ result: Result<(AuthCredential, String?), Error>) {
        switch result {
        case .success(let data):
            completion?.resume(returning: data)
        case .failure(let error):
            completion?.resume(throwing: error)
        }
        completion = nil
        currentNonce = nil
    }
}

extension AppleAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let identityToken = appleIDCredential.identityToken,
            let idTokenString = String(data: identityToken, encoding: .utf8),
            let nonce = currentNonce
        else {
            finish(.failure(AuthError.internalError))
            return
        }

        let authCodeString: String?
        if let authCodeData = appleIDCredential.authorizationCode {
            authCodeString = String(data: authCodeData, encoding: .utf8)
        } else {
            authCodeString = nil
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        finish(.success((credential, authCodeString)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign In failed: \(error.localizedDescription)")
        finish(.failure(AuthError(firebaseError: error)))
    }
}

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Mirrors the scene-lookup fallback used in GoogleAuthService for consistency.
        let windowScene =
            UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            ?? UIApplication.shared.connectedScenes.first as? UIWindowScene

        if let window = windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first {
            return window
        }

        return UIWindow(windowScene: windowScene!)
    }
}

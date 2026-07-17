//
//  GoogleAuthService.swift
//  MyJourney
//

import FirebaseAuth
import FirebaseCore
import GoogleSignIn

class GoogleAuthService {
    @MainActor
    func getCredential() async throws(AuthError) -> AuthCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw .internalError
        }

        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windowScene.windows.first?.rootViewController
        else {
            throw .internalError
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.internalError
            }

            return GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    @MainActor
    func startSignInFlow() async throws(AuthError) {
        do {
            let credential = try await getCredential()
            try await Auth.auth().signIn(with: credential)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError(firebaseError: error)
        }
    }
}

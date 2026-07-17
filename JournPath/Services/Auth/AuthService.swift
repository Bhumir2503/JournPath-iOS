//
//  AuthService.swift
//  MyJourney
//

import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation

class AuthService {

    // MARK: - Dependencies
    private let emailAuth = EmailAuthService()
    private let appleAuth = AppleAuthService()
    private let googleAuth = GoogleAuthService()

    // MARK: - Email Auth Flow
    func signUp(email: String, password: String) async throws(AuthError) {
        try await emailAuth.signUp(email: email, password: password)   
    }

    func signIn(email: String, password: String) async throws(AuthError) {
        try await emailAuth.signIn(email: email, password: password)
    }

    // MARK: - Apple Auth Flow
    func appleSignIn() async throws(AuthError) {
        try await appleAuth.startSignInFlow()
    }

    // MARK: - Google Auth Flow
    func googleSignIn() async throws(AuthError) {
        try await googleAuth.startSignInFlow()
    }

    // MARK: - Logout
    func signOut() throws(AuthError) {
        do {
            try Auth.auth().signOut()
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    // MARK: - Email Account Management
    func sendPasswordReset(email: String) async throws(AuthError) {
        try await emailAuth.sendPasswordReset(email: email.cleanUpEmail)
    }

    func changeEmail(currentPassword: String, newEmail: String) async throws(AuthError) {
        try await emailAuth.changeEmail(currentPassword: currentPassword, newEmail: newEmail)
    }

    func changePassword(currentPassword: String, newPassword: String) async throws(AuthError) {
        try await emailAuth.changePassword(currentPassword: currentPassword, newPassword: newPassword)
    }

    // MARK: - Profile Management
    func updateProfile(payload: [String: Any]) async throws(AuthError) {
        do {
            _ = try await Functions.functions()
                .httpsCallable("updateUserProfile")
                .call(payload)
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    // MARK: - Account Linking
    @MainActor
    func linkApple() async throws(AuthError) -> AuthDataResult {
        guard let user = Auth.auth().currentUser else { throw .notSignedIn }

        do {
            let (credential, _) = try await appleAuth.getCredential()
            return try await user.link(with: credential)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    @MainActor
    func linkGoogle() async throws(AuthError) -> AuthDataResult {
        guard let user = Auth.auth().currentUser else { throw .notSignedIn }

        do {
            let credential = try await googleAuth.getCredential()
            return try await user.link(with: credential)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    @MainActor
    func unlinkApple() async throws(AuthError) {
        guard let user = Auth.auth().currentUser else { throw .notSignedIn }

        do {
            // Force re-authentication to get a fresh authorization code
            let (_, authCode) = try await appleAuth.getCredential()

            if let authCode = authCode {
                try await Auth.auth().revokeToken(withAuthorizationCode: authCode)
            }

            let _ = try await user.unlink(fromProvider: "apple.com")
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    func unlink(providerId: String) async throws(AuthError) {
        guard let user = Auth.auth().currentUser else { throw .notSignedIn }

        do {
            let _ = try await user.unlink(fromProvider: providerId)
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    // MARK: - Account Deletion
    @MainActor
    func deleteAccount(email: String? = nil, password: String? = nil) async throws(AuthError) {
        // guard let user = Auth.auth().currentUser else { throw .notSignedIn }

        // let hasApple = user.providerData.contains { $0.providerID == "apple.com" }
        // let hasGoogle = user.providerData.contains { $0.providerID == "google.com" }

        // do {
        //     if let provider = provider {
        //         if provider == .apple {
        //             let (credential, authCode) = try await appleAuth.getCredential()
        //             try await user.reauthenticate(with: credential)
        //             if let authCode = authCode {
        //                 try await Auth.auth().revokeToken(withAuthorizationCode: authCode)
        //             }
        //         } else if provider == .google {
        //             let credential = try await googleAuth.getCredential()
        //             try await user.reauthenticate(with: credential)
        //         }
        //     } else if let email = email, let password = password, !email.isEmpty, !password.isEmpty {
        //         let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        //         try await user.reauthenticate(with: credential)
        //     } else if hasApple {
        //         // Force re-authentication to get a fresh authorization code
        //         let (credential, authCode) = try await appleAuth.getCredential()

        //         // Re-authenticate to satisfy recent-login requirement for deletion
        //         try await user.reauthenticate(with: credential)

        //         if let authCode = authCode {
        //             try await Auth.auth().revokeToken(withAuthorizationCode: authCode)
        //         }
        //     } else if hasGoogle {
        //         let credential = try await googleAuth.getCredential()
        //         try await user.reauthenticate(with: credential)
        //     }

        //     // Actually delete the Firebase user.
        //     // This will trigger any Auth onDelete cloud functions to clean up Firestore/Storage.
        //     try await user.delete()
        // } catch let error as AuthError {
        //     throw error
        // } catch {
        //     throw AuthError(firebaseError: error)
        // }
    }
}

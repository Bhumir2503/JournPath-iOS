//
//  EmailAuthService.swift
//  MyJourney
//

import FirebaseAuth
import Foundation

class EmailAuthService {

    func signUp(email: String, password: String) async throws(AuthError) {
        do {
            try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    func signIn(email: String, password: String) async throws(AuthError) {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    func sendPasswordReset(email: String) async throws(AuthError) {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    func changeEmail(currentPassword: String, newEmail: String) async throws(AuthError) {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw AuthError.notSignedIn
        }
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            try await user.reauthenticate(with: credential)
            try await user.updateEmail(to: newEmail)
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    func changePassword(currentPassword: String, newPassword: String) async throws(AuthError) {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw AuthError.notSignedIn
        }
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

}

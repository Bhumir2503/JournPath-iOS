//
//  AuthViewModel.swift
//  MyJourney
//

import Combine
import FirebaseAuth
import SwiftUI

@Observable
class AuthViewModel {
    var error: AuthError? = nil

    private let authService = AuthService()

    func signUpErrorChecker(email: String, password: String, reenterPassword: String) throws(AuthError) {
        if password != reenterPassword {
            throw AuthError.passwordsDoNotMatch
        } else if email.isEmpty {
            throw AuthError.missingEmail
        } else if password.isEmpty {
            throw AuthError.missingPassword
        } else if !email.isValidEmail {
            throw AuthError.invalidEmailFormat
        } else if !password.isValidPassword {
            throw AuthError.invalidPasswordFormat
        }
    }

    func authenticate(isSignUpMode: Bool, email: String, password: String, reenterPassword: String) async throws {
        let cleanEmail = email.cleanUpEmail

        do {
            if isSignUpMode {

                try signUpErrorChecker(email: cleanEmail, password: password, reenterPassword: reenterPassword)
                try await authService.signUp(email: cleanEmail, password: password)
            } else {
                let _ = try await authService.signIn(email: cleanEmail, password: password)
            }
        } catch {
            self.error = error
            throw error
        }

    }

    func sendResetPasswordLink(email: String) async throws {
        let cleanEmail = email.cleanUpEmail
        do {
            try await authService.sendPasswordReset(email: cleanEmail)
        } catch {
            self.error = error
            throw error
        }
    }

}

// MARK: - Social Login
extension AuthViewModel {
    @MainActor
    func appleSignIn() async throws {
        do {
            let _ = try await authService.appleSignIn()
        } catch {
            throw error
        }

    }

    @MainActor
    func googleSignIn() async throws {

        do {
            let _ = try await authService.googleSignIn()
        } catch {
            throw error
        }

    }
}

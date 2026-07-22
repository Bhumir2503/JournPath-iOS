//
// SessionStore.swift
// MyJourney
//

import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

enum AuthState {
    case loading
    case loggedIn
    case loggedOut
}

@MainActor
@Observable
class UserManager {
    var currentUser: FirebaseAuth.User?
    var state: AuthState = .loading
    var isHandlingManualAuth: Bool = false

    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    init() {
        setupAuthListener()
    }

    private func setupAuthListener() {
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { [weak self] in
                await self?.handleAuthStateChange(user: user)
            }
        }
    }

    private func handleAuthStateChange(user: FirebaseAuth.User?) async {
        self.currentUser = user

        if user != nil {
            if !self.isHandlingManualAuth {
                self.state = .loggedIn
            }
        } else {
            if !self.isHandlingManualAuth {
                self.state = .loggedOut
            }
        }
    }

    func finalizeSignIn() {
        self.isHandlingManualAuth = false
        if self.currentUser != nil { self.state = .loggedIn }
    }

    func finalizeSignOut() {
        self.isHandlingManualAuth = false
        if self.currentUser == nil { self.state = .loggedOut }
    }
}

// MARK: - Computed Properties (Source of Truth: Firestore)
extension UserManager {
    var uid: String? { currentUser?.uid }

    var displayName: String {
        currentUser?.displayName ?? "Anonymous"
    }

    var email: String {
        currentUser?.email ?? "No Email"
    }

    var photoURL: String? {
        currentUser?.photoURL?.absoluteString
    }

    // Checking providers via Firestore Source of Truth
    var isGoogleLinked: Bool {
        currentUser?.providerData.contains(where: { $0.providerID == "google.com" }) ?? false
    }

    var isAppleLinked: Bool {
        currentUser?.providerData.contains(where: { $0.providerID == "apple.com" }) ?? false
    }

    var isEmailPasswordLinked: Bool {
        currentUser?.providerData.contains(where: { $0.providerID == "password" }) ?? false
    }
}

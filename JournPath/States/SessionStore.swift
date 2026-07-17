//
// SessionStore.swift
// MyJourney
//

import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

// 1. Define a model that matches your Firestore "users" collection
struct UserProfile: Codable, Equatable {
    let uid: String
    let displayName: String
    let photoURL: String
    let linkedProviders: [String]
    let createdAt: Date
}

enum AuthState {
    case loading
    case loggedIn
    case loggedOut
}

@MainActor
@Observable
class SessionStore {
    var currentUser: FirebaseAuth.User?
    var userProfile: User?  // The true source of truth for your UI
    var state: AuthState = .loading
    var isHandlingManualAuth: Bool = false

    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    private var firestoreListener: ListenerRegistration?

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

        // Remove old listener whenever the auth state changes
        firestoreListener?.remove()

        if let user = user {
            // Listen to the Firestore document in real-time
            firestoreListener = Firestore.firestore()
                .collection("users")
                .document(user.uid)
                .addSnapshotListener { [weak self] snapshot, _ in
                    guard let self = self else { return }

                    if let data = try? snapshot?.data(as: User.self) {
                        self.userProfile = data
                    }

                    // Only update state if we aren't in the middle of a manual auth flow
                    if !self.isHandlingManualAuth {
                        self.state = .loggedIn
                    }
                }
        } else {
            self.userProfile = nil
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
extension SessionStore {
    var uid: String? { currentUser?.uid }

    var displayName: String {
        userProfile?.displayName ?? currentUser?.displayName ?? "Anonymous"
    }

    var email: String {
        currentUser?.email ?? "No Email"
    }

    var photoURL: String? {
        userProfile?.photoURL ?? currentUser?.photoURL?.absoluteString
    }

    // Checking providers via Firestore Source of Truth
    var isGoogleLinked: Bool {
        userProfile?.linkedProviders.contains("google.com") ?? false
    }

    var isAppleLinked: Bool {
        userProfile?.linkedProviders.contains("apple.com") ?? false
    }

    var isEmailPasswordLinked: Bool {
        userProfile?.linkedProviders.contains("password") ?? false
    }
}

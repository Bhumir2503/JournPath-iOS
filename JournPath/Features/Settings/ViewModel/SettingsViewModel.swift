//
//  SettingsViewModel.swift
//  MyJourney
//
//  Created by Bhumir Patel on 3/13/26.
//

import AuthenticationServices
import Combine
import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

@MainActor
class SettingsViewModel: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert = false
    
    private var currentNonce: String?
    private let db = Firestore.firestore()
    
    private enum AppleAuthFlow {
        case none
        case deleteAccount
    }
    
    private var currentFlow: AppleAuthFlow = .none
    
    var isAppleUser: Bool {
        guard let user = Auth.auth().currentUser else { return false }
        return user.providerData.contains { $0.providerID == "apple.com" }
    }
    
    func deleteAccount() async throws {
        guard isAppleUser else { return }
        // Trigger Apple reauthentication and token revocation
        try startAppleDeleteFlow()
    }
    
    func deleteAccountWithPassword(password: String) async {
        guard let user = Auth.auth().currentUser,
              let email = user.email else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Reauthenticate user
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
            
            // 2. Delete Firestore User Document
            let uid = user.uid
            try await db.collection("Users").document(uid).delete()
            
            // 3. Delete Firebase User
            try await user.delete()
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func startAppleDeleteFlow() throws {
        currentFlow = .deleteAccount
        let nonce = generateNonce()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    private func generateNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in charset[Int(byte) % charset.count] }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

extension SettingsViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("[SettingsViewModel] Unable to retrieve AppleIDCredential")
            return
        }
        
        guard currentNonce != nil else {
            fatalError("Invalid state: A login callback was received, but no login request was sent.")
        }
        
        guard let appleAuthCode = appleIDCredential.authorizationCode else {
            print("[SettingsViewModel] Unable to fetch authorization code")
            return
        }
        
        guard let authCodeString = String(data: appleAuthCode, encoding: .utf8) else {
            print("[SettingsViewModel] Unable to serialize auth code string from data: \(appleAuthCode.debugDescription)")
            return
        }
        
        isLoading = true
        Task {
            do {
                guard let user = Auth.auth().currentUser else { return }
                let uid = user.uid
                
                // 1. Revoke Apple Token in Firebase Auth
                try await Auth.auth().revokeToken(withAuthorizationCode: authCodeString)
                
                // 2. Delete Firestore User Document
                try await db.collection("Users").document(uid).delete()
                
                // 3. Delete Firebase User
                try await user.delete()
                
                print("[SettingsViewModel] Apple account successfully deleted and revoked.")
            } catch {
                print("[SettingsViewModel] Error deleting Apple account: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true
            }
            isLoading = false
            currentFlow = .none
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("[SettingsViewModel] Apple Re-Auth failed: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        showErrorAlert = true
        currentFlow = .none
    }
}

extension SettingsViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            fatalError("No active window scene found")
        }
        return window
    }
}

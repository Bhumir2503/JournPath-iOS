import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AppRouter.self) private var router
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String? = nil
    @State private var showingReauthAlert = false
    @State private var isDeleting = false

    @Environment(SessionStore.self) private var sessionStore
    private let authService = AuthService()

    var body: some View {
        Form {
            // Warning Details Section
            Section {
                WarningRow(icon: "map.fill", text: "All your saved trips and itineraries")
                WarningRow(icon: "photo.fill", text: "All uploaded files, photos, and memories")
                WarningRow(icon: "person.text.rectangle.fill", text: "Your profile and linked account data")
            } header: {
                Text("What you will lose")
            }



            // Action Section
            Section {
                VStack(spacing: 16) {
                    IconTextButton(
                        title: "Delete Account",
                        iconName: "trash.fill",
                        isLoading: isDeleting,
                        isDisabled: isDeleting,
                        buttonColor: .red,
                        successColor: .red
                    ) {
                        showingReauthAlert = true
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: errorMessage)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } footer: {
                Text("This action is completely permanent and cannot be undone. If you proceed, you will immediately lose access to your data.")
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Re-authenticate to delete", isPresented: $showingReauthAlert) {
            if sessionStore.isEmailPasswordLinked {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                SecureField("Password", text: $password)
                
                Button("Delete using Email", role: .destructive) {
//                    deleteWith(provider: .email)
                }
                .disabled(email.isEmpty || password.isEmpty)
            }
            
            if sessionStore.isAppleLinked {
                Button("Delete using Apple", role: .destructive) {
//                    deleteWith(provider: .apple)
                }
            }
            
            if sessionStore.isGoogleLinked {
                Button("Delete using Google", role: .destructive) {
//                    deleteWith(provider: .google)
                }
            }
            
            Button("Cancel", role: .cancel) {
                email = ""
                password = ""
            }
        } message: {
            if sessionStore.isEmailPasswordLinked {
                Text("Please enter your email and password to confirm deletion, or select a linked provider.")
            } else {
                Text("Please select a linked provider to confirm deletion.")
            }
        }
    }
    
    private func deleteWith() {
//        Task {
//            isDeleting = true
//            errorMessage = nil
//            do {
//                if provider == .email {
//                    try await authService.deleteAccount(email: email, password: password)
//                } else {
//                    try await authService.deleteAccount(provider: provider)
//                }
//                router.popToRoot()
//            } catch {
//                if let localizedError = error as? LocalizedError {
//                    errorMessage = localizedError.errorDescription ?? error.localizedDescription
//                } else {
//                    errorMessage = AuthError(firebaseError: error).errorDescription
//                }
//                isDeleting = false
//            }
//        }
    }
}

struct WarningRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.red)
                .frame(width: 24)
            Text(text)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        DeleteAccountView()
    }
}

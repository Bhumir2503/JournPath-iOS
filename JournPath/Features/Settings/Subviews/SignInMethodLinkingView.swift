import SwiftUI
import FirebaseAuth

struct SignInMethodLinkingView: View {
    @Environment(UserManager.self) private var sessionStore
    private let authService = AuthService()

    @State private var errorMessage: String? = nil
    @State private var loadingProviderID: String? = nil
    @State private var showingEmailLinkSheet = false
    
    // Provider IDs from Firebase
    private let appleProviderID = "apple.com"
    private let googleProviderID = "google.com"
    private let emailProviderID = "password"

    private var linkedProvidersCount: Int {
        var count = 0
        if sessionStore.isAppleLinked { count += 1 }
        if sessionStore.isGoogleLinked { count += 1 }
        if sessionStore.isEmailPasswordLinked { count += 1 }
        return count
    }

    private var canUnlink: Bool {
        linkedProvidersCount > 1
    }

    var body: some View {
        Form {
            Section {
                ProviderRow(
                    providerName: "Apple",
                    iconName: "applelogo",
                    isLinked: sessionStore.isAppleLinked,
                    allowUnlink: canUnlink,
                    isLoading: loadingProviderID == appleProviderID,
                    iconColor: .primary
                ) {
                    handleAction(providerId: appleProviderID, isLinked: sessionStore.isAppleLinked)
                }
                
                ProviderRow(
                    providerName: "Google",
                    iconName: "google",
                    isSFSymbol: false,
                    isLinked: sessionStore.isGoogleLinked,
                    allowUnlink: canUnlink,
                    isLoading: loadingProviderID == googleProviderID,
                    iconColor: nil
                ) {
                    handleAction(providerId: googleProviderID, isLinked: sessionStore.isGoogleLinked)
                }
                
                ProviderRow(
                    providerName: "Email & Password",
                    iconName: "envelope.fill",
                    isLinked: sessionStore.isEmailPasswordLinked,
                    allowUnlink: canUnlink,
                    isLoading: loadingProviderID == emailProviderID,
                    iconColor: .gray
                ) {
                    if sessionStore.isEmailPasswordLinked {
                        handleAction(providerId: emailProviderID, isLinked: true)
                    } else {
                        showingEmailLinkSheet = true
                    }
                }
            } header: {
                Text("Linked Accounts")
            } footer: {
                Text("Linking multiple accounts allows you to sign in using any of these methods.")
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Linked Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingEmailLinkSheet) {
            NavigationStack {
                LinkEmailView()
                    .environment(sessionStore)
            }
        }
    }

    private func handleAction(providerId: String, isLinked: Bool) {
        Task {
            loadingProviderID = providerId
            do {
                if isLinked {
                    // Unlink
                    if providerId == appleProviderID {
                        try await authService.unlinkApple()
                    } else {
                        try await authService.unlink(providerId: providerId)
                    }
                } else {
                    // Link
                    if providerId == appleProviderID {
                        _ = try await authService.linkApple()
                    } else if providerId == googleProviderID {
                        _ = try await authService.linkGoogle()
                    }
                }
                
                // Force token refresh so SessionStore updates its state
                if let user = Auth.auth().currentUser {
                    try await user.reload()
                    _ = try await user.getIDTokenResult(forcingRefresh: true)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            loadingProviderID = nil
        }
    }
}

// MARK: - Link Email View
struct LinkEmailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(UserManager.self) private var sessionStore
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String? = nil
    @State private var showPasswordRequirements = false
    
    private enum Field: Hashable {
        case email, password, confirmPassword
    }
    @FocusState private var focusedField: Field?
    
    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
            } footer: {
                Text("Enter the email you want to use for this account.")
            }
            
            Section {
                HStack {
                    SecureField("Password", text: $password)
                        .focused($focusedField, equals: .password)

                    Button {
                        showPasswordRequirements.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(password.isValidPassword ? .green : .gray)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showPasswordRequirements) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password Requirements")
                                .font(.headline)
                                .padding(.bottom, 2)
                            RequirementRow(text: "At least 8 characters", isMet: password.count >= 8)
                            RequirementRow(text: "Contains uppercase letter", isMet: password.containsUppercase)
                            RequirementRow(text: "Contains lowercase letter", isMet: password.containsLowercase)
                            RequirementRow(text: "Contains a number", isMet: password.containsNumber)
                        }
                        .padding()
                        .presentationCompactAdaptation(.popover)
                    }
                }
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .focused($focusedField, equals: .confirmPassword)
            } header: {
                Text("Security")
            } footer: {
                Text("Enter a strong password to protect your account.")
            }
            
            // Submit Section
            VStack(spacing: 16) {
                AsyncIconTextButton(
                    title: "Link Email",
                    iconName: "link",
                    isDisabled: !email.isValidEmail || !password.isValidPassword || password != confirmPassword,
                    buttonColor: .blue,
                    successColor: .green
                ) {
                    focusedField = nil
                    errorMessage = nil
                    
                    guard password == confirmPassword else {
                        errorMessage = "Passwords do not match"
                        return
                    }
                    
                    do {
                        guard let user = Auth.auth().currentUser else { return }
                        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                        _ = try await user.link(with: credential)
                        
                        try await user.reload()
                        _ = try await user.getIDTokenResult(forcingRefresh: true)
                    } catch {
                        if let localizedError = error as? LocalizedError {
                            errorMessage = localizedError.errorDescription ?? error.localizedDescription
                        } else {
                            errorMessage = AuthError(firebaseError: error).errorDescription
                        }
                        throw error
                    }
                } closingAction: {
                    dismiss()
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
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Link Email")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Provider Row
struct ProviderRow: View {
    let providerName: String
    let iconName: String
    var isSFSymbol: Bool = true
    let isLinked: Bool
    var allowUnlink: Bool = true
    var isLoading: Bool = false
    var iconColor: Color? = nil
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            if isSFSymbol {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(iconColor ?? .primary)
                    .frame(width: 32)
            } else {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .frame(width: 32)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(providerName)
                    .font(.body)

                Text(isLinked ? "Connected" : "Not Connected")
                    .font(.caption)
                    .foregroundColor(isLinked ? .green : .secondary)
            }

            Spacer()

            // Native Button
            if isLoading {
                ProgressView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                Button(action: action) {
                    Text(isLinked ? "Unlink" : "Link")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(isLinked ? .red : .blue)
                .disabled(isLinked && !allowUnlink)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SignInMethodLinkingView()
            .environment(UserManager())
    }
}

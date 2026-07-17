import SwiftUI

enum ChangeEmailError: Error {
    case emailsDoNotMatch
    case invalidEmail
    case invalidCurrentPassword
}

extension ChangeEmailError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emailsDoNotMatch:
            return "Emails do not match"
        case .invalidEmail:
            return "Invalid email address"
        case .invalidCurrentPassword:
            return "Invalid current password"
        }
    }
}

struct ChangeEmailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(SessionStore.self) var session

    @State private var currentPassword = ""
    @State private var newEmail = ""
    @State private var confirmEmail = ""
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    private enum Field: Hashable {
        case currentPassword, newEmail, confirmEmail
    }
    @FocusState private var focusedField: Field?

    private let authService = AuthService()
    private let userDB = UserDatabaseService()
    
    private var isValid: Bool {
        !currentPassword.isEmpty && newEmail.isValidEmail && newEmail == confirmEmail
    }

    func updateEmail() async throws {
        guard newEmail == confirmEmail else {
            throw ChangeEmailError.emailsDoNotMatch
        }
        guard !currentPassword.isEmpty else {
            throw ChangeEmailError.invalidCurrentPassword
        }
        guard newEmail.isValidEmail else {
            throw ChangeEmailError.invalidEmail
        }

        try await authService.changeEmail(currentPassword: currentPassword, newEmail: newEmail)
    }

    var body: some View {
        Form {
            // Current Password Section
            Section {

                SecureField("Current Password", text: $currentPassword)
                    .focused($focusedField, equals: .currentPassword)

            } footer: {
                Text("You must enter your existing password to authorize changes and verify your identity.")
            }

            // New Credentials Section
            Section {

                TextField("New Email", text: $newEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .newEmail)

                TextField("Confirm New Email", text: $confirmEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .confirmEmail)
            } header: {
                Text("New Credentials")
            }

            // Submit Section
            VStack(spacing: 16) {
                AsyncIconTextButton(
                    title: "Update Email",
                    iconName: "envelope.fill",
                    isDisabled: !isValid,
                    buttonColor: .blue,
                    successColor: .blue
                ) {
                    focusedField = nil
                    errorMessage = nil
                    successMessage = nil
                    do {
                        try await updateEmail()
                        successMessage = "Your email has been successfully updated."
                    } catch {
                        if let localizedError = error as? LocalizedError {
                            errorMessage = localizedError.errorDescription ?? error.localizedDescription
                        } else {
                            errorMessage = AuthError(firebaseError: error).errorDescription
                        }
                        throw error
                    }
                } closingAction: {
                    // Do nothing, let the user read the message and dismiss manually
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if let successMessage {
                    Text(successMessage)
                        .font(.footnote)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: errorMessage)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: successMessage)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

        }
        .scrollIndicators(.hidden)
        .navigationTitle("Change Email")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ChangeEmailView()
    }
}

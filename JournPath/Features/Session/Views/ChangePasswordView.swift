//
//  ChangePasswordView.swift
//  MyJourney
//
//  Created by Bhumir Patel on 4/17/26.
//

import SwiftUI

enum ChangePasswordError: Error {
    case passwordsDoNotMatch
    case invalidPassword
    case invalidCurrentPassword
}

extension ChangePasswordError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .passwordsDoNotMatch:
            return "Passwords do not match"
        case .invalidPassword:
            return "Invalid password"
        case .invalidCurrentPassword:
            return "Invalid current password"
        }
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String? = nil

    private enum Field: Hashable {
        case currentPassword, newPassword, confirmPassword
    }
    @FocusState private var focusedField: Field?

    @State private var showPasswordRequirements = false

    private let authService = AuthService()

    private var isValid: Bool {
        !currentPassword.isEmpty && newPassword.isValidPassword && newPassword == confirmPassword
    }

    func updatePassword() async throws {
        guard newPassword == confirmPassword else {
            throw ChangePasswordError.passwordsDoNotMatch
        }
        guard !currentPassword.isEmpty else {
            throw ChangePasswordError.invalidCurrentPassword
        }
        guard newPassword.isValidPassword else {
            throw ChangePasswordError.invalidPassword
        }

        do {
            try await authService.changePassword(currentPassword: currentPassword, newPassword: newPassword)
        } catch {
            throw error
        }
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
                HStack {
                    SecureField("New Password", text: $newPassword)
                        .focused($focusedField, equals: .newPassword)

                    Button {
                        showPasswordRequirements.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(newPassword.isValidPassword ? .green : .gray)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showPasswordRequirements) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password Requirements")
                                .font(.headline)
                                .padding(.bottom, 2)
                            RequirementRow(text: "At least 8 characters", isMet: newPassword.count >= 8)
                            RequirementRow(text: "Contains uppercase letter", isMet: newPassword.containsUppercase)
                            RequirementRow(text: "Contains lowercase letter", isMet: newPassword.containsLowercase)
                            RequirementRow(text: "Contains a number", isMet: newPassword.containsNumber)
                        }
                        .padding()
                        .presentationCompactAdaptation(.popover)
                    }
                }

                SecureField("Confirm New Password", text: $confirmPassword)
                    .focused($focusedField, equals: .confirmPassword)
            } header: {
                Text("New Credentials")
            }

            // Submit Section
            VStack(spacing: 16) {
                AsyncIconTextButton(
                    title: "Update Password",
                    iconName: "lock.fill",
                    isDisabled: !isValid,
                    buttonColor: .brand,
                    successColor: .brand
                ) {
                    focusedField = nil
                    errorMessage = nil
                    do {
                        try await updatePassword()
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
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
    }
}

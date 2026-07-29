//
//  ForgotPasswordView.swift
//  MyJourney
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Binding var email: String
    @FocusState private var isEmailFocused: Bool
    @State private var errorClearTask: Task<Void, Never>? = nil

    @State private var error: AuthError? = nil
    private let authService = AuthService()

    var body: some View {
        VStack(spacing: 24) {
            headerView

            VStack(spacing: 0) {
                emailInput
                    .padding(.vertical, 14)
            }
            .padding(.horizontal)
            .background(.ultraThinMaterial)
            .cornerRadius(28)

            submitButtonSection
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .onAppear {
            isEmailFocused = true
        }
        .onDisappear {
            error = nil
        }
        .onChange(of: error) { _, newValue in
            if newValue != nil {
                errorClearTask?.cancel()
                errorClearTask = Task {
                    try? await Task.sleep(for: .seconds(3.5))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        withAnimation(.easeInOut) {
                            error = nil
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

extension ForgotPasswordView {

    private var headerView: some View {
        VStack {
            HStack {
                Text("Forgot Password")
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textCase(nil)

                Spacer()

                Button(action: {
                    error = nil
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .frame(width: 20, height: 28)
                }
                .buttonStyle(.glass)
            }
            .padding(.top, 8)

            HStack {
                Image("JournPathIcon-Default")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .cornerRadius(16)

                Text("Recover your JournPath account using your email")
                    .font(.subheadline)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .textCase(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var emailInput: some View {
        HStack {
            Image(systemName: "envelope.fill")
                .foregroundColor(.secondary)
                .frame(width: 25)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($isEmailFocused)
                .submitLabel(.done)
                .onSubmit {
                    isEmailFocused = false
                }
        }
    }

    private var submitButtonSection: some View {
        VStack(spacing: 16) {
            if let error = error {
                Text(error.recoverySuggestion ?? "Unknown Error Occurred. Please Contact Support")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.top, -8)
            }

            if email.isValidEmail {
                AsyncIconTextButton(
                    title: "Send Reset Link",
                    buttonColor: .blue,
                    successColor: .blue,
                    successIconName: "paperplane.fill",
                    isFormStyle: false,
                ) {
                    try await sendResetPasswordLink()
                } closingAction: {
                    dismiss()
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: email.isValidEmail)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: error)
    }
}

extension ForgotPasswordView {
    func sendResetPasswordLink() async throws {
        do {
            try await authService.sendPasswordReset(email: email.cleanUpEmail)
        } catch {
            self.error = error
            throw error
        }
    }
}

#Preview {
    @Previewable @State var email = ""

    ForgotPasswordView(email: $email)
}

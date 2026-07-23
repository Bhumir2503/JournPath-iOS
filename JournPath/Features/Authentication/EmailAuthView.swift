import SwiftUI

enum EmailAuthTextField: Equatable {
    case email
    case password
    case reenterPassword
}

struct EmailAuthView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AuthViewModel.self) private var authVM
    @Environment(UserManager.self) private var session
    @FocusState private var focusedField: EmailAuthTextField?

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var reenterPassword: String = ""
    @State private var isSignUpMode: Bool = true
    @State private var isForgotPasswordMode: Bool = false
    @State private var showPasswordRequirements: Bool = false
    @State private var errorClearTask: Task<Void, Never>? = nil

    private let modeTransitionAnimation: Animation = .smooth(duration: 0.35, extraBounce: 0)

    var canSubmit: Bool {
        let isPasswordsMatch = !isSignUpMode || (password == reenterPassword && !reenterPassword.isEmpty)
        let isEmailValid = email.isValidEmail
        let isPasswordValid = isSignUpMode ? password.isValidPassword : password.count >= 6
        return isEmailValid && isPasswordValid && isPasswordsMatch
    }

    var body: some View {
        DynamicSheet(animation: modeTransitionAnimation) {
            VStack(spacing: 24) {
                headerView

                VStack(spacing: 0) {
                    emailInput
                        .padding(.vertical, 14)
                    Divider().padding(.leading, 36)

                    passwordInput
                        .padding(.vertical, 14)

                    if isSignUpMode {
                        Divider().padding(.leading, 36)
                        reenterPasswordInput
                            .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal)
                .background(.ultraThinMaterial)
                .cornerRadius(28)

                submitButtonSection
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .animation(modeTransitionAnimation, value: isSignUpMode)
        }
        .onDisappear {
            session.finalizeSignIn()
        }
        .sheet(isPresented: $isForgotPasswordMode) {
            DynamicSheet(animation: modeTransitionAnimation) {
                ForgotPasswordView(email: $email)
            }
            .interactiveDismissDisabled()
        }
        .onChange(of: authVM.error) { _, newValue in
            if newValue != nil {
                errorClearTask?.cancel()
                errorClearTask = Task {
                    try? await Task.sleep(for: .seconds(3.5))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        withAnimation(.easeInOut) {
                            authVM.error = nil
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

extension EmailAuthView {

    private var headerView: some View {
        VStack {
            HStack {
                Text("Continue with Email")
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textCase(nil)

                Spacer()

                Button(action: {
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

                Text(isSignUpMode ? "Sign up for JournPath using your email." : "Sign in to JournPath using your email.")
                    .font(.subheadline)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .textCase(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(isSignUpMode)
                    .transition(.blurReplace)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var reenterPasswordInput: some View {
        HStack {
            Image(systemName: "repeat")
                .foregroundColor(.secondary)
                .frame(width: 25)

            SecureField("Re-enter Password", text: $reenterPassword)
                .textContentType(.password)
                .focused($focusedField, equals: .reenterPassword)
                .submitLabel(.done)
            
            if !reenterPassword.isEmpty {
                Image(systemName: password == reenterPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(password == reenterPassword ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.snappy, value: reenterPassword)
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
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .password
                }
        }
    }

    private var passwordInput: some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundColor(.secondary)
                .frame(width: 25)

            SecureField("Password", text: $password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(isSignUpMode ? .next : .done)
                .onSubmit {
                    if isSignUpMode {
                        focusedField = .reenterPassword
                    }
                }

            if isSignUpMode {
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
            } else {
                Button("Forgot?") {
                    authVM.error = nil
                    isForgotPasswordMode.toggle()
                }
                .font(.footnote.bold())
                .foregroundColor(.blue)
                .buttonStyle(.plain)
                .transition(.blurReplace)
            }
        }
    }

    private var submitButtonSection: some View {
        VStack(spacing: 16) {
            if let error = authVM.error {
                Text(error.recoverySuggestion ?? "Unknown Error Occurred. Please Contact Support")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.top, -8)
            }

            if canSubmit {
                AsyncIconTextButton(
                    title: isSignUpMode ? "Create Account" : "Sign In",
                    buttonColor: .blue,
                    successColor: .blue,
                    isFormStyle: false
                ) {
                    session.isHandlingManualAuth = true
                    try await authVM.authenticate(isSignUpMode: isSignUpMode, email: email, password: password, reenterPassword: reenterPassword)
                } closingAction: {
                    dismiss()
                }
            }
            footerToggleMode
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: canSubmit)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: authVM.error)
    }

    private var footerToggleMode: some View {
        Button {
            let selection = UISelectionFeedbackGenerator()
            selection.selectionChanged()
            authVM.error = nil
            withAnimation(modeTransitionAnimation) {
                isSignUpMode.toggle()
            }
            focusedField = .email
        } label: {
            Text(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                .id(isSignUpMode)
                .transition(.blurReplace)
        }
        .frame(maxWidth: .infinity)
        .font(.subheadline)
    }
}

struct RequirementRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .gray)
            Text(text)
                .foregroundColor(isMet ? .primary : .gray)
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.2).ignoresSafeArea()
        EmailAuthView()
            .environment(AuthViewModel())
            .environment(UserManager())
    }
}

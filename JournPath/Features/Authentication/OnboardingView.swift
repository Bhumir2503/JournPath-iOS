//
//  OnboardingView.swift
//  MyJourney
//
//  Created by Bhumir Patel on 9/29/25.
//

import Lottie
import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) var colorScheme
    @State var authVM = AuthViewModel()
    @State var isShowingEmailForm: Bool = false
    @Environment(UserManager.self) private var session

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 24) {

                    LottieView(animation: .named("TicketsLottie"))
                        .playing()
                        .looping()

                    VStack {
                        Text("JournPath")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Every journey, in your pocket.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 16)

                }

                VStack(spacing: 16) {
                    googleSignInButton
                    appleSignInButton

                    HStack {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(height: 1)

                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        Rectangle()
                            .fill(.quaternary)
                            .frame(height: 1)
                    }  // Or Divider

                    emailSignInButton

                    TermsAndPrivacyTextRow()
                }  //Apple and Email Buttons
                .padding(.horizontal)
                .padding(.top, 32)
                .padding(.bottom, min(geometry.safeAreaInsets.bottom + 20, 32))
                .background(

                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .environment(authVM)
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $isShowingEmailForm) {
            EmailAuthView()
                .interactiveDismissDisabled()
                .environment(authVM)
        }
    }

    var googleSignInButton: some View {
        AsyncIconTextButton(
            title: "Continue with Google",
            iconName: "google",
            isSFSymbol: false,
            textColor: colorScheme == .dark ? .black : .white,
            buttonColor: colorScheme == .dark ? .white : .black,
            successColor: colorScheme == .dark ? .white : .black
        ) {
            session.isHandlingManualAuth = true
            try await authVM.googleSignIn()
        } closingAction: {
            session.finalizeSignIn()
        }
    }

    var appleSignInButton: some View {
        AsyncIconTextButton(
            title: "Continue with Apple",
            iconName: "applelogo",
            textColor: colorScheme == .dark ? .black : .white,
            buttonColor: colorScheme == .dark ? .white : .black,
            successColor: colorScheme == .dark ? .white : .black
        ) {
            session.isHandlingManualAuth = true
            try await authVM.appleSignIn()
        } closingAction: {
            session.finalizeSignIn()
        }
    }

    var emailSignInButton: some View {
        IconTextButton(title: "Continue with Email", iconName: "envelope.fill", textColor: .primary) {
            isShowingEmailForm = true
        }
    }
}

struct TermsAndPrivacyTextRow: View {
    @State private var showTerms = false
    @State private var showPrivacy = false

    var body: some View {
        VStack(spacing: 4) {
            Text("By continuing, you agree to our")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Button("Terms of Service") {
                    // Handle terms
                    showTerms = true
                }
                .font(.caption2)
                .foregroundStyle(.blue)

                Text("and")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button("Privacy Policy") {
                    // Handle privacy
                    showPrivacy = true
                }
                .font(.caption2)
                .foregroundStyle(.blue)
            }
        }
        .padding(.top, 8)
        .sheet(isPresented: $showTerms) {
            TermsOfService()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicy()
        }
    }
}

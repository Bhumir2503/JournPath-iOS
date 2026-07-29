import FirebaseAuth
import Kingfisher
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) var session
    @Environment(AppRouter.self) private var router
    @Environment(\.requestReview) var requestReview

    @State private var showLogoutAlert: Bool = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
        return "Version \(version)"
    }

    var body: some View {
        List {
            profileHeader
            accountAndSecurity
            support
            logoutButton
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

// MARK: - Profile Header
extension SettingsView {
    @ViewBuilder
    var profileHeader: some View {
        Section {
            HStack {
                KFImage(URL(string: session.photoURL ?? ""))
                    .placeholder {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.gray.opacity(0.8))
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName)
                        .font(.title3)

                    Text(session.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            NavigationLink {
                EditProfileView()
            } label: {
                Label("Edit Profile", systemImage: "pencil")
            }
        }
    }
}

// MARK: - Support
extension SettingsView {
    @ViewBuilder
    var support: some View {
        Section(header: Text("Support")) {
            NavigationLink {
                PrivacyPolicy()
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            NavigationLink {
                TermsOfService()
            } label: {
                Label("Terms of Service", systemImage: "text.page")
            }

            Button {
                requestReview()
            } label: {
                Label("Love MyJourney? Leave a Review!", systemImage: "heart.fill")
                    .foregroundColor(.pink)
            }
        }
    }
}

// MARK: - Account & Security
extension SettingsView {
    @ViewBuilder
    var accountAndSecurity: some View {
        Section(header: Text("Account & Security")) {
            NavigationLink {
                ChangeEmailView()
            } label: {
                HStack {
                    Label("Change Email", systemImage: "envelope")
                    if !session.isEmailPasswordLinked {
                        Spacer()
                        thirdPartyBadges
                    }
                }
            }
            .disabled(!session.isEmailPasswordLinked)

            NavigationLink {
                ChangePasswordView()
            } label: {
                HStack {
                    Label("Change Password", systemImage: "lock.rotation")
                    if !session.isEmailPasswordLinked {
                        Spacer()
                        thirdPartyBadges
                    }
                }
            }
            .disabled(!session.isEmailPasswordLinked)

            NavigationLink {
                SignInMethodLinkingView()
            } label: {
                Label("Linked Sign-In Methods ", systemImage: "person.badge.key")
            }
        }
    }

    @ViewBuilder
    var thirdPartyBadges: some View {
        HStack(spacing: 8) {
            if session.isAppleLinked {
                Image(systemName: "applelogo")
                    .foregroundColor(.secondary)
            }
            if session.isGoogleLinked {
                Image("google")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            }
        }
    }
}

// MARK: - Logout Button
extension SettingsView {
    @ViewBuilder
    var logoutButton: some View {
        Section {
            IconTextButton(
                title: "Log Out",
                iconName: "rectangle.portrait.and.arrow.right",
                buttonColor: .red,
                isFormStyle: false
            ) {
                showLogoutAlert = true
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    router.popToRoot()
                    try? Auth.auth().signOut()
                }
            } message: {
                Text("Are you sure you want to log out of MyJourney?")
            }
        } footer: {
            Text("\(appVersion)")
                .padding(.top)
                .font(.footnote)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

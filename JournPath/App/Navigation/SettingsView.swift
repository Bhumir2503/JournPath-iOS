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
            #if DEBUG
                developerSection
            #endif
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
                Label {
                    Text("Edit Profile").foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "pencil").foregroundStyle(Color.brand)
                }
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
                Label {
                    Text("Privacy Policy").foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "hand.raised").foregroundStyle(Color.brand)
                }
            }

            NavigationLink {
                TermsOfService()
            } label: {
                Label {
                    Text("Terms of Service").foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "text.page").foregroundStyle(Color.brand)
                }
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
                    Label {
                        Text("Change Email").foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "envelope").foregroundStyle(Color.brand)
                    }
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
                    Label {
                        Text("Change Password").foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "lock.rotation").foregroundStyle(Color.brand)
                    }
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
                Label {
                    Text("Linked Sign-In Methods").foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "person.badge.key").foregroundStyle(Color.brand)
                }
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

// MARK - Developer Section
#if DEBUG
    extension SettingsView {
        @ViewBuilder
        var developerSection: some View {
            Section(header: Text("Developer")) {
                NavigationLink("Cache Inspector") { ContainerBrowserView() }
            }
        }
    }
#endif

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

import SwiftUI

struct PrivacyPolicy: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                Text("Last updated: July 2026")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Divider()
                
                policySection(
                    title: "1. Information We Collect",
                    content: """
                    When you use MyJourney, we collect information you provide directly to us. This includes your name, email address, profile picture, and any travel itineraries, dates, or notes you save in the app. \n\nSince we use Firebase for authentication and database services, some basic device and usage data may also be collected automatically to ensure the app functions securely.
                    """
                )
                
                policySection(
                    title: "2. How We Use Your Information",
                    content: """
                    We use the information we collect to:
                    • Provide, maintain, and improve the MyJourney app.
                    • Authenticate your account securely.
                    • Sync your travel data across your devices.
                    • Send you technical notices or support messages.
                    """
                )
                
                policySection(
                    title: "3. Data Storage and Security",
                    content: """
                    Your data is stored securely using Google's Firebase infrastructure (Firestore, Firebase Storage, and Firebase Authentication). We implement reasonable security measures to protect your personal information against unauthorized access or alteration. However, no internet-based service is 100% secure.
                    """
                )
                
                policySection(
                    title: "4. Sharing Your Information",
                    content: """
                    We do not sell your personal information. We may share your information only in the following situations:
                    • With your consent.
                    • To comply with legal obligations.
                    • With third-party service providers (like Google Firebase) strictly to operate the MyJourney service.
                    """
                )
                
                policySection(
                    title: "5. Your Rights",
                    content: """
                    You have the right to access, update, or delete your personal information at any time. You can manage your profile data directly within the MyJourney settings or delete your account entirely, which will wipe your trips and data from our active databases.
                    """
                )
                
                policySection(
                    title: "6. Contact Us",
                    content: """
                    If you have any questions or concerns about this Privacy Policy, please contact our support team.
                    """
                )
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func policySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
    }
}

#Preview {
    PrivacyPolicy()
}

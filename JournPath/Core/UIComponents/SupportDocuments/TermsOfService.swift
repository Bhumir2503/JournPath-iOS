import SwiftUI

struct TermsOfService: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                Text("Last updated: July 2026")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Divider()
                
                termsSection(
                    title: "1. Acceptance of Terms",
                    content: """
                    By creating an account or using MyJourney, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our application.
                    """
                )
                
                termsSection(
                    title: "2. User Accounts",
                    content: """
                    You are responsible for safeguarding your account credentials. We provide sign-in methods via Email/Password and Apple Sign-In. You must notify us immediately upon becoming aware of any breach of security or unauthorized use of your account.
                    """
                )
                
                termsSection(
                    title: "3. User Generated Content",
                    content: """
                    MyJourney allows you to create, save, and manage travel itineraries and notes. You retain all rights to the content you post in the app. However, by posting content, you grant us the right to store and process it using our backend infrastructure (Firebase) strictly to provide the service to you.
                    """
                )
                
                termsSection(
                    title: "4. Acceptable Use",
                    content: """
                    You agree not to use the app to store illegal, abusive, or harmful content. We reserve the right to suspend or terminate your account if we believe you have violated these guidelines.
                    """
                )
                
                termsSection(
                    title: "5. Termination",
                    content: """
                    We may terminate or suspend your access to the app immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms. You may also delete your account at any time via the app settings.
                    """
                )
                
                termsSection(
                    title: "6. Changes to Terms",
                    content: """
                    We reserve the right to modify or replace these Terms at any time. We will try to provide at least 30 days' notice prior to any new terms taking effect.
                    """
                )
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func termsSection(title: String, content: String) -> some View {
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
    TermsOfService()
}

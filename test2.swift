import SwiftUI

struct Participant: Identifiable {
    var id: String
    var displayName: String
}

struct TestView: View {
    @State private var pendingKick: Participant?
    
    var body: some View {
        Text("Test")
            .confirmationDialog(
                "Remove Participant?",
                isPresented: Binding(
                    get: { pendingKick != nil },
                    set: { if !$0 { pendingKick = nil } }
                ),
                presenting: pendingKick
            ) { member in
                Button(role: .destructive) {
                    
                } label: {
                    Text("Remove \(member.displayName)")
                }
                Button("Cancel", role: .cancel) {
                    pendingKick = nil
                }
            } message: { member in
                Text("Are you sure you want to remove \(member.displayName)?")
            }
    }
}

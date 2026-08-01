import SwiftUI

struct StorageView: View {
    var body: some View {
        NavigationStack {
            VStack {
                ContentUnavailableView(
                    "No files yet",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Add photos or documents to your trip")
                )
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle("Storage Hub")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

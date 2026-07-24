import SwiftUI

struct StorageCard: View {
    @State private var showingAttachmentsSheet = false

    var body: some View {
        Button {
            showingAttachmentsSheet = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)

                Text("Add Attachments")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("PDFs, Photos, Documents")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingAttachmentsSheet) {
            Text("Attachments Sheet")
        }
    }
}

import SwiftUI

struct AttachmentsCard: View {
    @Binding var activeSource: FilePickerSource?

    var body: some View {
        Menu {
            ForEach(FilePickerSource.allCases) { source in
                Button {
                    activeSource = source
                } label: {
                    Label(source.title, systemImage: source.systemImage)
                }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.secondary)
                
                Text("Add Attachments")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }
}

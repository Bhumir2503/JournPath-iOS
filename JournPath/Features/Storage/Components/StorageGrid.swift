import SwiftUI

struct StorageGrid: View {
    let files: [StorageFile]
    let currentUid: String?
    let thumbnailURL: (StorageFile) -> URL?
    let progress: (String) -> Double?
    let onTap: (StorageFile) -> Void
    let onRetry: (StorageFile) -> Void
    let onDelete: (StorageFile) -> Void

    private let spacing: CGFloat = 12

    /// Fixed three columns. `.flexible()` divides the available width evenly,
    /// so cells grow with the screen instead of wrapping to four on a Pro Max.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(files) { file in
                StorageFileCell(
                    file: file,
                    currentUid: currentUid,
                    thumbnailURL: thumbnailURL(file),
                    progress: file.id.flatMap(progress),
                    onTap: { onTap(file) },
                    onRetry: { onRetry(file) }
                )
                .contextMenu {
                    if file.isReady {
                        Button {
                            onTap(file)
                        } label: {
                            Label("View", systemImage: "eye")
                        }
                    }
                    if canDelete(file) {
                        Button(role: .destructive) {
                            onDelete(file)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, spacing)
        .animation(.default, value: files.map(\.id))
    }

    private func canDelete(_ file: StorageFile) -> Bool {
        file.uploadedBy == currentUid
    }
}
// Files/Hub/StorageGridMetrics.swift
import SwiftUI

struct StorageGrid: View {
    let files: [StorageFile]
    let currentUid: String?
    let thumbnailURL: (StorageFile) -> URL?
    let progress: (String) -> Double?
    let onTap: (StorageFile) -> Void
    let onRetry: (StorageFile) -> Void
    let onDelete: (StorageFile) -> Void

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(
                .fixed(StorageGridMetrics.thumbnailSize),
                spacing: StorageGridMetrics.spacing
            ),
            count: StorageGridMetrics.columns
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: StorageGridMetrics.spacing) {
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
                    if file.uploadedBy == currentUid {
                        Button(role: .destructive) {
                            onDelete(file)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)  // centers the fixed-width grid
        .padding(.horizontal, StorageGridMetrics.horizontalPadding)
        .animation(.default, value: files.map(\.id))
    }
}

enum StorageGridMetrics {
    static let columns = 3
    static let spacing: CGFloat = 12
    static let horizontalPadding: CGFloat = 12

    /// Thumbnail is square; the label block is a fixed two-line strip so every
    /// cell is the same height regardless of filename length.
    static let labelHeight: CGFloat = 32
    static let labelSpacing: CGFloat = 6

    /// Derived from the narrowest supported width (iPhone SE, 375pt) so the
    /// same cell size works everywhere. On wider screens the grid centers
    /// with extra gutter rather than stretching.
    static let thumbnailSize: CGFloat = {
        let available = 375 - (horizontalPadding * 2) - (spacing * CGFloat(columns - 1))
        return floor(available / CGFloat(columns))  // 109
    }()

    static var cellHeight: CGFloat {
        thumbnailSize + labelSpacing + labelHeight
    }
}

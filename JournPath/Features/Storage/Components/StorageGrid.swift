// Files/Hub/StorageGridMetrics.swift
import SwiftUI

struct StorageGrid: View {
    let files: [StorageFile]
    let currentUid: String?
    let thumbnailURL: (StorageFile) -> URL?
    let progress: (String) -> Double?

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(),
                spacing: 12
            ),
            count: 3
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(files) { file in
                StorageFileCell(
                    file: file,
                    currentUid: currentUid,
                    thumbnailURL: thumbnailURL(file),
                    progress: file.id.flatMap(progress),
                )
            }
        }
        .padding(.horizontal)
        .animation(.default, value: files.map(\.id))
    }
}


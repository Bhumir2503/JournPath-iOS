// Files/Hub/StorageGridMetrics.swift
import SwiftUI

struct StorageGrid: View {
    let files: [StorageFile]
    let progress: (String) -> Double?
    
    @Binding var isSelecting: Bool
    @Binding var selectedFileIds: Set<String>

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
                    progress: file.id.flatMap(progress),
                    isSelecting: $isSelecting,
                    isSelected: Binding(
                        get: { file.id.map { selectedFileIds.contains($0) } ?? false },
                        set: { isSet in 
                            guard let id = file.id else { return }
                            if isSet { selectedFileIds.insert(id) } 
                            else { selectedFileIds.remove(id) }
                        }
                    )
                )
            }
        }
        .padding(.horizontal)
        .animation(.default, value: files.map(\.id))
    }
}


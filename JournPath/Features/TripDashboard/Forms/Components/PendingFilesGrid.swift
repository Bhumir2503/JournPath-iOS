import QuickLook
import SwiftUI

struct PendingFilesGrid: View {
    let files: [PendingFile]
    let onRemove: (String) -> Void
    
    @State private var previewURL: URL?
    
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(files) { file in
                Button {
                    previewURL = file.localPath
                } label: {
                    VStack(alignment: .center, spacing: 6) {
                        preview(for: file)
                            .frame(maxWidth: 120, maxHeight: 120)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    onRemove(file.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                        .padding(6)
                                }
                            }
                        
                        VStack(spacing: 2) {
                            Text(file.originalName)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.primary)
                            
                            let byteFormatter = ByteCountFormatter()
                            Text(byteFormatter.string(fromByteCount: Int64(file.byteSize)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.default, value: files.map(\.id))
        .quickLookPreview($previewURL)
    }
    
    @ViewBuilder
    private func preview(for file: PendingFile) -> some View {
        ZStack {
            Color(uiColor: .tertiarySystemBackground)
            if file.isImage, let data = try? Data(contentsOf: file.localPath), let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: file.isImage ? "photo" : "doc.fill")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
    }
}

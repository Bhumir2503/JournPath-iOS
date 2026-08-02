import Kingfisher
import SwiftUI

struct StorageFileCell: View {
    let file: StorageFile
    let currentUid: String?
    let thumbnailURL: URL?
    let progress: Double?

    var body: some View {
        Button(action: {}) {
            VStack(alignment: .center, spacing: 6) {
                preview
                .frame(maxWidth: 120, maxHeight: 120)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .center, spacing: 1) {
                    Text(file.originalName)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary)

                    Text(file.displaySize)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var preview: some View {
        ZStack {
            Color(uiColor: .tertiarySystemBackground)

            if let thumbnailURL {
                KFImage(thumbnailURL)
                    .placeholder { placeholderIcon }
                    .resizable()
                    .scaledToFill()
            } else if let localPath = file.localPath(currentUid: currentUid) {
                LocalPreviewImage(localPath: localPath, isImage: file.isImage)
            } else {
                placeholderIcon
            }
        }
        .clipped()
        .opacity(file.isInFlight ? 0.65 : 1)
    }

    private var placeholderIcon: some View {
        Image(systemName: file.systemImageName)
            .font(.title2)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var overlays: some View {
        switch file.status {
        case .uploading:
            if let progress {
                ZStack {
                    Color.black.opacity(0.25)
                    ProgressView(value: progress)
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
        case .failed, .pending, .uploaded:
            EmptyView()
        }
    }

    private func badge(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(color, in: Circle())
    }
}

struct LocalPreviewImage: View {
    let localPath: URL
    let isImage: Bool

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.clear
            }
        }
        .task(id: localPath) {
            guard isImage else { return }
            let path = localPath
            image = await Task.detached(priority: .utility) {
                guard let data = try? Data(contentsOf: path) else { return nil }
                return UIImage(data: data)?
                    .preparingThumbnail(of: CGSize(width: 300, height: 300))
            }.value
        }
    }
}

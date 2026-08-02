import Kingfisher
import SwiftUI

struct StorageFileCell: View {
    let file: StorageFile
    let currentUid: String?
    let thumbnailURL: URL?
    let progress: Double?
    let onTap: () -> Void
    let onRetry: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                preview
                    .aspectRatio(1, contentMode: .fit)  // square, width comes from the column
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .topTrailing) { statusBadge.padding(5) }
                    .overlay { overlays }

                Text(file.originalName)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)  // "IMG_…519.HEIC" beats "IMG_75…"
                    .foregroundStyle(.primary)

                Text(file.displaySize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
        case .failed:
            ZStack {
                Color.black.opacity(0.4)
                if file.quotaRejected {
                    Text("Storage full")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(4)
                } else if file.uploadedBy == currentUid {
                    Button(action: onRetry) {
                        Image(systemName: "arrow.clockwise")
                            .font(.callout.bold())
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        case .pending, .uploaded:
            EmptyView()
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch file.status {
        case .pending:
            badge("clock.fill", .gray)
        case .uploading:
            badge("arrow.up", .blue)
        case .failed:
            badge("exclamationmark", .red)
        case .uploaded:
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

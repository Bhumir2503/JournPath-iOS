import Kingfisher
import QuickLookThumbnailing
import SwiftUI

struct AttachmentThumbnailView: View {
    let attachmentURL: URL?
    var remoteThumbnailURL: URL? = nil
    let size: CGSize
    let fallbackIcon: String
    let fallbackColor: Color

    @Environment(\.displayScale) var displayScale
    @State private var thumbnailImage: UIImage?

    var body: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let remoteURL = remoteThumbnailURL {
                KFImage(remoteURL)
                    .placeholder { _ in
                        ProgressView()
                            .frame(width: size.width, height: size.height)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .onFailure { error in
                        print("KFImage Error: \(error)")
                        thumbnailImage = nil
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                fallbackIconView
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }

    private var fallbackIconView: some View {
        Image(systemName: fallbackIcon)
            .font(.system(size: size.width * 0.55))
            .foregroundColor(fallbackColor)
            .frame(width: size.width, height: size.height)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func generateThumbnail() {
        guard let url = attachmentURL else { return }

        // 1. Capture value types to use safely inside the background task
        let targetSize = size
        let currentScale = displayScale

        // 2. Push all disk I/O and image processing to a background thread
        Task.detached(priority: .userInitiated) {

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(targetSize.width, targetSize.height) * currentScale,
                kCGImageSourceShouldCacheImmediately: true,
            ]

            // Try the extremely fast CGImageSource approach first
            if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
            {
                let generatedImage = UIImage(cgImage: cgImage)

                // 3. Jump back to the Main Thread to update the UI
                await MainActor.run {
                    self.thumbnailImage = generatedImage
                }
                return
            }

            // Fallback: Use QLThumbnailGenerator for non-image documents (PDFs, docs)
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: targetSize,
                scale: currentScale,
                representationTypes: .thumbnail
            )

            QLThumbnailGenerator.shared.generateRepresentations(for: request) { thumbnail, type, error in
                if let generatedThumbnail = thumbnail {
                    // QLThumbnailGenerator callbacks happen on background threads,
                    // so we must explicitly route this back to the main thread too.
                    DispatchQueue.main.async {
                        self.thumbnailImage = generatedThumbnail.uiImage
                    }
                }
            }
        }
    }
}

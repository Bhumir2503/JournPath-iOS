import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Image downsampling and PDF rendering. Pure functions over their arguments —
/// no filesystem staging, no state, nothing injectable.
///
/// Threading: CPU-bound re-encoding. Call from a detached task, never from
/// the main actor.
enum MediaCompressor {

    // MARK: - Configuration

    /// Long edge in pixels. 2048 keeps receipts legible when zoomed while
    /// cutting a 12MP photo to roughly a tenth its size.
    static let maxImageDimension: CGFloat = 2048
    static let jpegQuality: CGFloat = 0.7

    /// Smaller target for avatars — they're only ever shown at ~40pt.
    static let avatarDimension: CGFloat = 512

    // MARK: - Image downsampling

    /// Uses ImageIO's thumbnail path rather than UIImage → resize → jpegData.
    /// The latter decodes the full bitmap first (~48 MB for one 12MP photo),
    /// which will get you jetsammed on a 10-photo multi-select.
    static func downsample(
        at source: URL,
        to destination: URL,
        maxDimension: CGFloat = maxImageDimension,
        quality: CGFloat = jpegQuality
    ) throws {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else {
            throw CompressionError.unreadableImage
        }
        try write(imageSource, to: destination, maxDimension: maxDimension, quality: quality)
    }

    static func downsample(
        data: Data,
        to destination: URL,
        maxDimension: CGFloat = maxImageDimension,
        quality: CGFloat = jpegQuality
    ) throws {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw CompressionError.unreadableImage
        }
        try write(imageSource, to: destination, maxDimension: maxDimension, quality: quality)
    }

    /// Data-in, data-out. For callers that never touch the filesystem —
    /// avatar upload, for instance.
    static func downsample(
        data: Data,
        maxDimension: CGFloat = maxImageDimension,
        quality: CGFloat = jpegQuality
    ) throws -> Data {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw CompressionError.unreadableImage
        }
        guard let cgImage = thumbnail(from: imageSource, maxDimension: maxDimension) else {
            throw CompressionError.unreadableImage
        }
        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output, UTType.jpeg.identifier as CFString, 1, nil
            )
        else { throw CompressionError.encodingFailed }

        CGImageDestinationAddImage(
            destination, cgImage,
            [
                kCGImageDestinationLossyCompressionQuality: quality
            ] as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.encodingFailed
        }
        return output as Data
    }

    // MARK: - PDF

    /// Renders scanned pages into a single Letter-sized PDF, fitting each page
    /// to the sheet rather than drawing at native camera resolution.
    static func makePDF(from images: [CGImage]) throws -> Data {
        guard !images.isEmpty else { throw CompressionError.emptyInput }

        var pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)  // Letter @ 72dpi
        let output = NSMutableData()

        guard let consumer = CGDataConsumer(data: output),
            let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil)
        else { throw CompressionError.encodingFailed }

        for image in images {
            context.beginPage(mediaBox: &pageRect)
            let size = CGSize(width: image.width, height: image.height)
            context.draw(image, in: AVMakeRect(aspectRatio: size, insideRect: pageRect))
            context.endPage()
        }
        context.closePDF()

        return output as Data
    }

    // MARK: - Internals

    private static func write(
        _ imageSource: CGImageSource,
        to destination: URL,
        maxDimension: CGFloat,
        quality: CGFloat
    ) throws {
        guard let cgImage = thumbnail(from: imageSource, maxDimension: maxDimension) else {
            throw CompressionError.unreadableImage
        }
        guard
            let imageDestination = CGImageDestinationCreateWithURL(
                destination as CFURL, UTType.jpeg.identifier as CFString, 1, nil
            )
        else { throw CompressionError.encodingFailed }

        CGImageDestinationAddImage(
            imageDestination, cgImage,
            [
                kCGImageDestinationLossyCompressionQuality: quality
            ] as CFDictionary)

        guard CGImageDestinationFinalize(imageDestination) else {
            try? FileManager.default.removeItem(at: destination)
            throw CompressionError.encodingFailed
        }
    }

    private static func thumbnail(from source: CGImageSource, maxDimension: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,  // bakes in EXIF rotation
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // MARK: - Errors

    enum CompressionError: LocalizedError {
        case unreadableImage
        case encodingFailed
        case emptyInput

        var errorDescription: String? {
            switch self {
            case .unreadableImage: "That image couldn't be read."
            case .encodingFailed: "Couldn't process that image."
            case .emptyInput: "Nothing to process."
            }
        }
    }
}

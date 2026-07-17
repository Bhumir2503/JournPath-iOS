import Foundation
import ImageIO
import UIKit

extension URL {
    func compressedImage(maxDimension: CGFloat = 1920.0, compressionQuality: CGFloat = 0.8) async -> Data? {
        await Task.detached(priority: .userInitiated) {

            return autoreleasepool {

                guard let imageSource = CGImageSourceCreateWithURL(self as CFURL, nil) else { return nil }

                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                ]

                guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else { return nil }

                let uiImage = UIImage(cgImage: downsampledImage)
                return uiImage.jpegData(compressionQuality: compressionQuality)
            }
        }.value
    }

    func getFileType() -> String {
        switch self.pathExtension.lowercased() {
        case "pdf": return "pdf"
        case "png", "jpg", "jpeg", "gif", "heic": return "image"
        case "mov", "mp4", "m4v": return "video"
        case "xls", "xlsx": return "excel"
        case "doc", "docx", "txt", "rtf": return "doc"
        default: return "other"
        }
    }
}
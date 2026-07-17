import Foundation
import UniformTypeIdentifiers

enum FileUtils {
    static func getFileType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension),
            let mimeType = type.preferredMIMEType
        {
            return mimeType
        }

        // Fallback for completely unknown binary files
        return "application/octet-stream"
    }
}

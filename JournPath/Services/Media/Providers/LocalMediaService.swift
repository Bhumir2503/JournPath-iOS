import Foundation
import UniformTypeIdentifiers

enum MediaError: LocalizedError {
    case fileTooLarge
    
    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "File is too large. Maximum allowed size is 5MB."
        }
    }
}

class LocalMediaService {

    /// Main function to process an input URL (either a Photo Picker URL or a File URL)
    func processInputURL(_ inputURL: URL) async throws -> (Data, String) {

        // 1. Request secure access to the user's file system (Crucial for iCloud/Files app)
        let secureAccess = inputURL.startAccessingSecurityScopedResource()

        // 2. Release the file when done, even if an error is thrown
        defer {
            if secureAccess { inputURL.stopAccessingSecurityScopedResource() }
        }

        // 3. Determine the Mime Type dynamically
        let mimeType = FileUtils.getFileType(for: inputURL)

        // 4. Checks if the data needs to be compressed (e.g. images, (Video in the future))
        let ext = inputURL.pathExtension.lowercased()
        let isImage = ["png", "jpg", "jpeg", "gif", "heic"].contains(ext)

        let finalData: Data

        if isImage {
            // COMPRESSION: Streams directly from the disk URL (No RAM spike).
            if let compressedData = await inputURL.compressedImage() {
                finalData = compressedData
            } else {
                finalData = try Data(contentsOf: inputURL)
            }
        } else {
            finalData = try Data(contentsOf: inputURL)
        }
        
        // 5. Enforce 5MB size limit
        let maxSize: Int = 5 * 1024 * 1024
        if finalData.count > maxSize {
            throw MediaError.fileTooLarge
        }

        return (finalData, mimeType)
    }
}

// MARK: - Cache Management
extension LocalMediaService {
    func getLocalFileURL(for tripId: String, fileId: String, fileName: String) -> URL {
        let fileManager = FileManager.default
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let tripFolderURL = cachesURL.appendingPathComponent("trips").appendingPathComponent(tripId)

        if !fileManager.fileExists(atPath: tripFolderURL.path) {
            try? fileManager.createDirectory(at: tripFolderURL, withIntermediateDirectories: true)
        }

        let ext = URL(fileURLWithPath: fileName).pathExtension
        let safeFileName = ext.isEmpty ? fileId : "\(fileId).\(ext)"
        return tripFolderURL.appendingPathComponent(safeFileName)
    }

    func getExistingLocalFileURL(for tripId: String, fileId: String) -> URL? {
        let fileManager = FileManager.default
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let tripFolderURL = cachesURL.appendingPathComponent("trips").appendingPathComponent(tripId)
        
        guard let files = try? fileManager.contentsOfDirectory(atPath: tripFolderURL.path) else { return nil }
        
        for file in files {
            // Check if the file starts with the fileId (to ignore the dynamic extension)
            if file.hasPrefix(fileId) {
                return tripFolderURL.appendingPathComponent(file)
            }
        }
        return nil
    }

    func isFileDownloadedLocally(tripId: String, fileId: String) -> Bool {
        return getExistingLocalFileURL(for: tripId, fileId: fileId) != nil
    }

    func removeLocalDownload(tripId: String, fileId: String) {
        if let localURL = getExistingLocalFileURL(for: tripId, fileId: fileId) {
            try? FileManager.default.removeItem(at: localURL)
        }
    }
}

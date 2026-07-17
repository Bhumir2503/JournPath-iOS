import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

class AttachmentService {

    private let localMediaService = LocalMediaService()
    private let fileStorageService = AttachmentStorageService()
    private let fileDatabaseService = AttachmentDatabaseService()

    func listenToAttachments(tripId: String, onUpdate: @escaping (_ files: [Attachment]) -> Void) -> () -> Void {

        return fileDatabaseService.listenToAttachments(tripId: tripId) { [weak self] newAttachments, removedAttachments in
            guard let self = self else { return }

            for removedAttachment in removedAttachments {
                self.localMediaService.removeLocalDownload(tripId: tripId, fileId: removedAttachment.id ?? "")
            }

            onUpdate(newAttachments)
        }
    }

    func compress(url: URL) async throws -> (Data, String) {
        return try await localMediaService.processInputURL(url)
    }

    func uploadData(tripId: String, fileName: String, fileData: Data, mimeType: String, onStateChange: @escaping (UploadState) -> Void) async throws {
        // 1. GENERATE IDENTIFIERS
        let fileId = UUID().uuidString
        let storagePath = "trips/\(tripId)/\(fileId)"

        // 2. GET USER ID
        let userId = try AuthUtils.requireUserId()

        // 3. UPLOAD DATA
        let _ = try await fileStorageService.upload(data: fileData, path: storagePath, tripId: tripId, fileId: fileId, mimeType: mimeType, fileName: fileName, userId: userId) { progress in
            onStateChange(.uploading(progress: progress))
        }
    }

    func rename(tripId: String, attachmentId: String, newName: String) async throws {
        try await fileDatabaseService.renameAttachment(tripId: tripId, attachmentId: attachmentId, newName: newName)
    }

    func download(url: URL, to localURL: URL, onProgress: @escaping (Double) -> Void) async throws {
        try await fileStorageService.download(url: url, to: localURL, onProgress: onProgress)
    }

    func delete(tripId: String, attachmentId: String) async throws {
        try await fileDatabaseService.deleteAttachment(tripId: tripId, attachmentId: attachmentId)
    }
}

// MARK: - Pass-Through Helpers for the ViewModel - Local Media Service
extension AttachmentService {
    func isFileDownloadedLocally(tripId: String, fileId: String) -> Bool {
        return localMediaService.isFileDownloadedLocally(tripId: tripId, fileId: fileId)
    }

    func getExistingLocalFileURL(tripId: String, fileId: String) -> URL? {
        return localMediaService.getExistingLocalFileURL(for: tripId, fileId: fileId)
    }

    func getLocalFileURL(tripId: String, fileId: String, fileName: String) -> URL {
        return localMediaService.getLocalFileURL(for: tripId, fileId: fileId, fileName: fileName)
    }

    func removeLocalDownload(tripId: String, fileId: String) {
        localMediaService.removeLocalDownload(tripId: tripId, fileId: fileId)
    }
}

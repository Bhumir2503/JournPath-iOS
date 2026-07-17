import FirebaseStorage
import Foundation

class AttachmentStorageService {
    private let storage = Storage.storage()

    func upload(data: Data, path: String, tripId: String, fileId: String, mimeType: String, fileName: String, userId: String, onProgress: @escaping (Double) -> Void) async throws -> URL {
        let storageRef = storage.reference().child(path)
        let uploadMetadata = StorageMetadata()
        uploadMetadata.contentType = mimeType

        uploadMetadata.customMetadata = [
            "tripId": tripId,
            "fileId": fileId,
            "fileName": fileName,
            "userId": userId,
        ]

        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = storageRef.putData(data, metadata: uploadMetadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    storageRef.downloadURL { url, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let url = url {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(throwing: URLError(.badServerResponse))
                        }
                    }
                }
            }

            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    onProgress(progress.fractionCompleted)
                }
            }
        }
    }
    func download(url: URL, to localURL: URL, onProgress: @escaping (Double) -> Void) async throws {
        let storageRef = storage.reference(forURL: url.absoluteString)

        return try await withCheckedThrowingContinuation { continuation in
            let downloadTask = storageRef.write(toFile: localURL) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }

            downloadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    onProgress(progress.fractionCompleted)
                }
            }
        }
    }

    func delete(url: String) async throws {
        let storageRef = storage.reference(forURL: url)
        try await storageRef.delete()
    }
}

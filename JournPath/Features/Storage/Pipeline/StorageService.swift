import FirebaseStorage
import Foundation

/// Uses Firebase Storage's own resumable upload machinery rather than a raw
/// background URLSession — it survives suspension and handles retry/backoff.
final class StorageService: @unchecked Sendable {
    static let shared = StorageService()

    private let storage: Storage
    private let lock = NSLock()
    private var tasks: [String: StorageUploadTask] = [:]

    init(storage: Storage = .storage()) { self.storage = storage }

    func upload(
        localURL: URL, to path: String, contentType: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let metadata = StorageMetadata()
        metadata.contentType = contentType

        return try await withCheckedThrowingContinuation { continuation in
            let ref = storage.reference(withPath: path)
            let task = ref.putFile(from: localURL, metadata: metadata)

            task.observe(.progress) { snapshot in
                guard let p = snapshot.progress, p.totalUnitCount > 0 else { return }
                onProgress(Double(p.completedUnitCount) / Double(p.totalUnitCount))
            }
            task.observe(.success) { [weak self] _ in
                self?.clear(path)
                continuation.resume()
            }
            task.observe(.failure) { [weak self] snapshot in
                self?.clear(path)
                continuation.resume(throwing: snapshot.error ?? StorageError.unknown)
            }

            lock.withLock { tasks[path] = task }
        }
    }

    func cancel(path: String) {
        lock.withLock {
            tasks[path]?.cancel()
            tasks[path] = nil
        }
    }

    func downloadURL(for path: String) async throws -> URL {
        try await storage.reference(withPath: path).downloadURL()
    }

    func download(path: String, maxBytes: Int64 = 200 * 1_024 * 1_024) async throws -> Data {
        try await storage.reference(withPath: path).data(maxSize: maxBytes)
    }

    func delete(path: String) async throws {
        try await storage.reference(withPath: path).delete()
    }

    private func clear(_ path: String) {
        lock.withLock { tasks[path] = nil }
    }

    enum StorageError: Error { case unknown }
}




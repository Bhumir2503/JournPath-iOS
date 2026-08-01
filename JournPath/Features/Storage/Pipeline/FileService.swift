import FirebaseFirestore
import Foundation

struct FileService {
    static let shared = FileService()

    private let db: Firestore
    init(db: Firestore = .firestore()) { self.db = db }

    private func ref(_ tripId: String) -> CollectionReference {
        db.collection("trips").document(tripId).collection("files")
    }

    /// Standalone add (storage hub). Forms use the batch in their own save
    /// so the parent doc and its files land atomically.
    func addFiles(_ files: [PendingFile], tripId: String, parentType: ParentType,
                  parentId: String, uid: String) throws {
        guard !files.isEmpty else { return }
        let batch = db.batch()
        for file in files {
            batch.setData(
                file.makeFileDoc(parentType: parentType, parentId: parentId, uid: uid),
                forDocument: ref(tripId).document(file.id)
            )
        }
        batch.commit()          // fire-and-forget: local cache applies immediately
    }

    func markUploading(tripId: String, fileId: String) async throws {
        try await ref(tripId).document(fileId).updateData([
            "status": FileStatus.uploading.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func markFailed(tripId: String, fileId: String, error: String, attempts: Int) async throws {
        try await ref(tripId).document(fileId).updateData([
            "status": FileStatus.failed.rawValue,
            "lastError": error,
            "uploadAttempts": attempts,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func retry(tripId: String, fileId: String) async throws {
        try await ref(tripId).document(fileId).updateData([
            "status": FileStatus.pending.rawValue,
            "lastError": NSNull(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func delete(tripId: String, fileId: String) async throws {
        try await ref(tripId).document(fileId).delete()
        FileCache.discard(id: fileId)
    }
}
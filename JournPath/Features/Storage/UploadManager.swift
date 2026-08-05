import FirebaseFirestore
import Foundation
import Observation

@Observable
@MainActor
final class UploadManager {
    private(set) var uploadProgress: [String: Double] = [:]

    private var uid: String?
    private var activeTripId: String?
    private var inFlight: Set<String> = []
    private let maxConcurrent = 3

    private var queueListener: ListenerRegistration?

    private let db: Firestore
    private let files = FileService.shared
    private let storage = StorageService.shared

    init(db: Firestore = .firestore()) {
        self.db = db
    }

    /// Removing a registration is thread-safe and not actor-isolated, so this
    /// is one of the few things a @MainActor class can safely do in deinit.
    deinit {

    }

    func start(tripId: String, uid: String) {
        guard activeTripId != tripId || self.uid != uid else { return }
        stop()
        activeTripId = tripId
        self.uid = uid

        AppLogger.store.info("[UploadManager] watching queue for trip \(tripId)")

        queueListener = db.collection("trips").document(tripId).collection("files")
            .whereField("uploadedBy", isEqualTo: uid)
            .whereField(
                "status",
                in: [
                    FileStatus.pending.rawValue,
                    FileStatus.uploading.rawValue,
                ]
            )
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handle(snapshot, error, tripId: tripId)
            }
    }

    func stop() {
        queueListener?.remove()
        queueListener = nil
        activeTripId = nil
        uid = nil
        inFlight.removeAll()
        uploadProgress.removeAll()
    }

    func progress(for fileId: String) -> Double? { uploadProgress[fileId] }

    private func handle(_ snapshot: QuerySnapshot?, _ error: Error?, tripId: String) {
        if let error {
            AppLogger.store.error("[UploadManager] queue listener: \(error.localizedDescription)")
            return
        }
        guard let documents = snapshot?.documents else { return }

        let queued =
            documents
            .compactMap { try? $0.data(as: StorageFile.self) }
            .sorted { $0.clientCreatedAt < $1.clientCreatedAt }

        for file in queued {
            guard inFlight.count < maxConcurrent else { break }
            guard let fileId = file.id, !inFlight.contains(fileId) else { continue }

            // Bytes gone — app reinstalled, or the cache was pruned.
            guard FileCache.exists(fileId) else {
                AppLogger.store.error("[UploadManager] missing local bytes for \(fileId)")
                Task {
                    try? await files.delete(tripId: tripId, fileId: fileId)
                }
                FileCache.discard(id: fileId) 
                continue
            }

            inFlight.insert(fileId)
            Task { await upload(file, fileId: fileId, tripId: tripId) }
        }
    }

    private func upload(_ file: StorageFile, fileId: String, tripId: String) async {
        defer {
            inFlight.remove(fileId)
            uploadProgress[fileId] = nil
        }

        let path = StoragePaths.original(tripId: tripId, fileId: fileId, ext: file.fileExtension)

        do {
            // First state other members can see — `pending` is filtered to the owner.
            if file.status == .pending {
                try await files.markUploading(tripId: tripId, fileId: fileId)
            }

            try await storage.upload(
                localURL: FileCache.path(for: fileId),
                to: path,
                contentType: file.mimeType
            ) { [weak self] fraction in
                Task { @MainActor in self?.uploadProgress[fileId] = fraction }
            }

            // processUpload owns `uploaded`, storagePath, and thumbnailPath.
            AppLogger.store.info("[UploadManager] uploaded \(fileId), awaiting processUpload")

        } catch {
            AppLogger.store.error("[UploadManager] \(fileId) failed: \(error.localizedDescription)")
            //clear and delete file
            FileCache.discard(id: fileId)
            try? await files.delete(tripId: tripId, fileId: fileId)
        }
    }
}

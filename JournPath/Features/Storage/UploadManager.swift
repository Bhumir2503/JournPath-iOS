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

    private(set) var failureNotices: [String: FailureNotice] = [:]

    struct FailureNotice: Identifiable {
        let id: String  // fileId
        let fileName: String
        let message: String
    }

    var hasFailures: Bool { !failureNotices.isEmpty }

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
            .whereField("deviceId", isEqualTo: DeviceID.current)
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
        guard let snapshot = snapshot else { return }

        for change in snapshot.documentChanges where change.type == .removed {
            FileUploadCache.discard(id: change.document.documentID)
        }

        let queued =
            snapshot.documents
            .compactMap { try? $0.data(as: StorageFile.self) }
            .sorted { $0.clientCreatedAt < $1.clientCreatedAt }

        for file in queued {
            guard inFlight.count < maxConcurrent else { break }
            guard let fileId = file.id, !inFlight.contains(fileId) else { continue }

            // Bytes gone — app reinstalled, or the cache was pruned.
            guard FileUploadCache.exists(fileId) else {
                AppLogger.store.error("[UploadManager] missing local bytes for \(fileId)")
                noteFailure(file, tripId: tripId, fileId: fileId, message: "File no longer available on this device")
                FileUploadCache.discard(id: fileId)
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
                localURL: FileUploadCache.path(for: fileId),
                to: path,
                contentType: file.mimeType
            ) { [weak self] fraction in
                guard let self else { return }
                Task { @MainActor in self.uploadProgress[fileId] = fraction }
            }

            // processUpload owns `uploaded`, storagePath, and thumbnailPath.
            AppLogger.store.info("[UploadManager] uploaded \(fileId), awaiting processUpload")
        } catch {
            AppLogger.store.error("[UploadManager] \(fileId) failed: \(error.localizedDescription)")
            noteFailure(file, tripId: tripId, fileId: fileId, message: "Upload failed. Try adding it again.")
            //clear
            FileUploadCache.discard(id: fileId)
        }
    }

    private func noteFailure(_ file: StorageFile, tripId: String, fileId: String, message: String) {
        failureNotices[fileId] = FailureNotice(
            id: fileId,
            fileName: file.originalName,
            message: message
        )

        Task {
            try? await Task.sleep(for: .seconds(4))
            try? await files.delete(tripId: tripId, fileId: fileId)
            failureNotices[fileId] = nil
        }
    }

    func dismissFailure(_ fileId: String, tripId: String) async {
        failureNotices[fileId] = nil
        try? await files.delete(tripId: tripId, fileId: fileId)
    }
}

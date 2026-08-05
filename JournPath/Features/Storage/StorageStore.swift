import FirebaseFirestore
import Foundation
import Observation

@Observable
@MainActor
final class StorageStore {
    let tripId: String

    private(set) var state: LoadState<[StorageFile]> = .idle
    private(set) var files: [StorageFile] = []

    @ObservationIgnored private var listener: ListenerRegistration?

    private let db: Firestore
    private let uid: String?

    init(
        tripId: String,
        uid: String?,
        db: Firestore = .firestore()
    ) {
        self.tripId = tripId
        self.uid = uid
        self.db = db
    }

    /// `remove()` isn't actor-isolated, so this is safe from a @MainActor deinit.
    deinit {
        listener?.remove()
    }

    // MARK: - Derived

    /// Bytes committed to docs but not yet counted by processUpload. Added to
    /// the server's storageUsedBytes so the quota bar reflects a 20-photo
    /// import while it's happening, not after.
    var inFlightBytes: Int {
        files.filter(\.isInFlight).reduce(0) { $0 + $1.byteSize }
    }

    var usedBytes: Int {
        files.filter { $0.status == .uploaded }
            .reduce(0) { $0 + $1.byteSize }
    }

    var uploadedFiles: [StorageFile] {
        files.filter { $0.status == .uploaded }
    }

    /// Pending, uploading, and failed — what the progress tray shows.
    var activeUploads: [StorageFile] {
        files.filter { $0.isInFlight || $0.status == .failed }
            .sorted { $0.clientCreatedAt < $1.clientCreatedAt }  // oldest first, matches queue order
    }

    var hasActiveUploads: Bool { !activeUploads.isEmpty }

    var isEmpty: Bool {
        if case .loaded = state { return files.isEmpty }
        return false
    }

    /// Files attached to a specific itinerary item or expense.
    func files(parentType: ParentType, parentId: String) -> [StorageFile] {
        files.filter { $0.parentType == parentType && $0.parentId == parentId }
    }

    func file(id: String) -> StorageFile? {
        files.first { $0.id == id }
    }

    /// Every file ID with local bytes that still matter — passed to
    /// FileCache.pruneOrphans so it never deletes a pending upload.
    func liveFileIds(uid: String?) -> Set<String> {
        guard let uid else { return [] }
        return Set(
            files
                .filter { $0.uploadedBy == uid && ($0.isInFlight || $0.status == .failed) }
                .compactMap(\.id)
        )
    }

    func start() {
        guard !tripId.isEmpty, listener == nil else { return }
        state = .loading

        AppLogger.store.info("[StorageStore] start \(self.tripId)")

        listener = db.collection("trips").document(tripId).collection("files")
            .order(by: "clientCreatedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handle(snapshot, error)
            }
    }

    func stop() {
        AppLogger.store.info("[StorageStore] stop \(self.tripId)")
        listener?.remove()
        listener = nil
    }

    private func handle(_ snapshot: QuerySnapshot?, _ error: Error?) {
        if let error {
            AppLogger.store.error("[StorageStore] listener: \(error.localizedDescription)")
            state = .failed(AnyAppError("Error", "Error loading files"))
            return
        }
        guard let snapshot else { return }

        reconcileCaches(with: snapshot)

        var decoded: [StorageFile] = []
        for document in snapshot.documents {
            do {
                decoded.append(try document.data(as: StorageFile.self))
            } catch {
                AppLogger.store.error("[StorageStore] decode \(document.documentID): \(error.localizedDescription)")
            }
        }
        files = decoded
        state = .loaded(decoded)
    }

    /// Keeps both local caches in step with the server.
    ///
    /// - `.modified` to `uploaded`: processUpload has published the thumbnail,
    ///   so the staged upload copy has no purpose left. Deleting earlier (right
    ///   after the transfer) would flicker the cell to a placeholder during the
    ///   second or two before the doc flips.
    /// - `.removed`: the file is gone for everyone. Drop the downloaded copy so
    ///   we're not holding bytes for something that no longer exists — this
    ///   fires on every member's device, not just the deleter's.
    private func reconcileCaches(with snapshot: QuerySnapshot) {
        for change in snapshot.documentChanges {
            let fileId = change.document.documentID

            switch change.type {

            case .removed:
                // Decode the last-known state to get the extension; if it fails,
                // sweep by ID instead so nothing is left behind.
                if let file = try? change.document.data(as: StorageFile.self) {
                    FileDownloadCache.remove(file, tripId: tripId)
                } else {
                    FileDownloadCache.remove(fileId: fileId, tripId: tripId)
                }
                FileUploadCache.discard(id: fileId)  // in case it never uploaded

            case .added, .modified:
                continue
            }
        }
    }
    /// Once processUpload publishes a thumbnail, the bytes are in Storage and
    /// the CDN copy is live — the staged upload copy has no purpose left.
    /// Deleting earlier (right after the transfer) would flicker the cell to a
    /// placeholder during the second or two before the doc flips.
    private func discardStagedBytesForCompletedUploads(in snapshot: QuerySnapshot) {
        guard let uid else { return }

        for change in snapshot.documentChanges where change.type == .modified {
            guard let file = try? change.document.data(as: StorageFile.self),
                file.status == .uploaded,
                file.uploadedBy == uid
            else { continue }

            let fileId = change.document.documentID
            guard FileUploadCache.exists(fileId) else { continue }

            AppLogger.store.info("[StorageStore] discarding staged bytes for \(fileId)")
            FileUploadCache.discard(id: fileId)
        }
    }
}

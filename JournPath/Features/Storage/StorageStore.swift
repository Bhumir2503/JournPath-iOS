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

    init(tripId: String, db: Firestore = .firestore()) {
        self.tripId = tripId
        self.db = db
    }

    /// `remove()` isn't actor-isolated, so this is safe from a @MainActor deinit.
    deinit {
        listener?.remove()
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
        guard let documents = snapshot?.documents else { return }

        var decoded: [StorageFile] = []
        for document in documents {
            do {
                decoded.append(try document.data(as: StorageFile.self))
            } catch {
                // Logged rather than dropped by `try?` — a schema drift shows
                // up as a missing file, which is near-impossible to debug.
                AppLogger.store.error("[StorageStore] decode \(document.documentID): \(error.localizedDescription)")
            }
        }
        files = decoded
        state = .loaded(decoded)
    }
}

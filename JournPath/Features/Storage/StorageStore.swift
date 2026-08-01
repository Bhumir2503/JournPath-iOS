import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation
import SwiftUI

@Observable
final class StorageStore {
    let tripId: String

    private var storageListener: ListenerRegistration?

    private(set) var files: [StorageFile] = []
    private(set) var hasLoaded = false

    private func filesRef() -> CollectionReference {
        Firestore.firestore()
            .collection("trips")
            .document(tripId)
            .collection("files")
    }

    init(tripId: String) {
        self.tripId = tripId
    }

    deinit {
        storageListener?.remove()
    }

    func start() {
        guard !tripId.isEmpty else { return }
        startStorageListener()
    }

    private func startStorageListener() {
        guard storageListener == nil else { return }

        AppLogger.store.info("[StorageStore] Started listening to files in trip: \(self.tripId)")

        storageListener = filesRef()
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    AppLogger.store.error("[StorageStore] Storage listener failed: \(error.localizedDescription)")
                    return
                }

                guard let snapshot else {
                    self.files = []
                    self.hasLoaded = true
                    return
                }

                self.files = snapshot.documents.compactMap { try? $0.data(as: StorageFile.self) }
                self.hasLoaded = true
            }
    }

    func stop() {
        AppLogger.store.info("[StorageStore] Stopped listening to files in trip: \(self.tripId)")
        storageListener?.remove()
        storageListener = nil
    }
}

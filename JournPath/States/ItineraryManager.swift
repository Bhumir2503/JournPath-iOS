import FirebaseFirestore
import Foundation
import SwiftUI

@Observable
class ItineraryManager {

    // MARK: - State

    var items: [ItineraryItem] = []
    var isLoading = true
    var error: String?

    // MARK: - Dependencies

    private let tripId: String
    private var listener: ListenerRegistration?

    init(tripId: String) {
        self.tripId = tripId
    }

    deinit {
        stopListening()
    }

    // MARK: - Lifecycle

    func startListening() {
        guard listener == nil else { return }
        isLoading = true

        AppLogger.managers.info("[ItineraryManager] Listening for items in trip: \(tripId)")

        listener = Firestore.firestore()
            .collection("trips")
            .document(tripId)
            .collection("itineraryItems")
            .order(by: "startTime")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    self?.handle(snapshot: snapshot, error: error)
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Snapshot Handling

    private func handle(snapshot: QuerySnapshot?, error: Error?) {
        isLoading = false

        if let error {
            self.error = error.localizedDescription
            AppLogger.managers.error("[ItineraryManager] Listener error: \(error.localizedDescription)")
            return
        }

        guard let documents = snapshot?.documents else {
            items = []
            return
        }

        items = documents.compactMap { document in
            do {
                return try document.data(as: ItineraryItem.self)
            } catch {
                AppLogger.managers.error(
                    "[ItineraryManager] Failed to decode \(document.documentID): \(error)")
                return nil
            }
        }
        self.error = nil
    }
}

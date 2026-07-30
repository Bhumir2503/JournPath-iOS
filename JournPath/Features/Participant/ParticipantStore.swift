import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation
import SwiftUI

@Observable
final class ParticipantStore {
    // MARK: - Dependencies
    let tripId: String

    // MARK: - State

    private(set) var allParticipants: [Participant] = []

    // MARK: - Slices

    var participants: [Participant] {
        allParticipants.filter { $0.status == .accepted }
    }

    var formerParticipants: [Participant] {
        allParticipants.filter { $0.status == .kicked }
    }

    // MARK: - Current user

    var me: Participant? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return allParticipants.first { $0.id == uid }
    }

    var amICaptain: Bool { me?.role == .captain }

    var amIKicked: Bool {
        guard let status = me?.status else { return false }
        return status == .kicked
    }

    var myRole: ParticipantRole { me?.role ?? .observer }

    // MARK: - Lookup

    /// Name resolution for Expenses and Itinerary, which store participant IDs.
    /// Looks across every status on purpose.
    func participant(id: String?) -> Participant? {
        guard let id else { return nil }
        return allParticipants.first { $0.id == id }
    }

    func displayName(for id: String?) -> String {
        participant(id: id)?.displayName ?? "Unknown"
    }

    // MARK: - Firestore

    private var listener: ListenerRegistration?
    private var participantsRef: CollectionReference {
        Firestore.firestore()
            .collection("trips")
            .document(tripId)
            .collection("participants")
    }

    init(tripId: String) {
        self.tripId = tripId
    }

    deinit {
        listener?.remove()
    }

    func start() {
        guard !tripId.isEmpty, listener == nil else { return }

        AppLogger.store.info("[ParticipantStore] Started listening to participants in trip: \(self.tripId)")

        listener = participantsRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                AppLogger.store.error("[ParticipantStore] Listener failed: \(error.localizedDescription)")
                return
            }

            let decoded = snapshot?.documents.compactMap({ try? $0.data(as: Participant.self) }) ?? []
            self.allParticipants = Self.sorted(decoded)
        }
    }

    func stop() {
        AppLogger.store.info("[ParticipantStore] Stopped listening to participants in trip: \(self.tripId)")
        listener?.remove()
        listener = nil
    }

    private static func sorted(_ members: [Participant]) -> [Participant] {
        members.sorted { a, b in
            if a.role.rank != b.role.rank { return a.role.rank > b.role.rank }
            if a.joinedAt != b.joinedAt { return a.joinedAt < b.joinedAt }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

}

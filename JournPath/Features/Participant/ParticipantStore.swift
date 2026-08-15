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

    /// The current user's own document, from its own listener. Under the
    /// security rules this is the only thing a removed member can still read —
    /// the roster query is a `list` and fails outright once you're kicked.
    private(set) var myMembership: Participant?

    /// True once either listener has delivered a snapshot. `me == nil` means two
    /// different things — not loaded yet, and not a member — and every
    /// "you were removed" check has to be able to tell them apart.
    private(set) var hasLoaded = false

    // MARK: - Slices

    var participants: [Participant] {
        allParticipants.filter { $0.status == .accepted }
    }

    /// Everyone who was on the trip and isn't now. Uses `isGone` rather than
    /// `== .kicked` so members who left voluntarily still appear — their
    /// expenses and itinerary entries reference them.
    var formerParticipants: [Participant] {
        allParticipants.filter { $0.status.isGone }
    }

    // MARK: - Current user

    /// `myMembership` takes precedence deliberately. When the roster listener
    /// dies on a kick it leaves a stale `accepted` document behind, so reading
    /// the array first would report you as still on the trip forever.
    var me: Participant? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return myMembership ?? allParticipants.first { $0.id == uid }
    }

    var amICaptain: Bool { me?.role == .captain }

    /// Not on the trip any more, by any route. Only meaningful once loaded.
    var amIRemoved: Bool {
        return me?.status != .accepted
    }

    var amIKicked: Bool { me?.status == .kicked }

    /// Least privilege while unknown.
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

    func displayPhoto(for id: String?) -> String {
        participant(id: id)?.photoURL ?? ""
    }

    // MARK: - Firestore

    private var rosterListener: ListenerRegistration?
    private var selfListener: ListenerRegistration?

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
        rosterListener?.remove()
        selfListener?.remove()
    }

    func start() {
        guard !tripId.isEmpty else { return }
        startRosterListener()
        startSelfListener()
    }

    /// One unfiltered query. No `whereField` — filtering by status is what made
    /// removed members invisible, and every slice above is derived instead.
    private func startRosterListener() {
        guard rosterListener == nil else { return }

        AppLogger.store.info("[ParticipantStore] Started listening to participants in trip: \(self.tripId)")

        rosterListener = participantsRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                // Expected after a kick: `list` requires active membership. The
                // stale array is deliberately left alone so names in old
                // expenses still resolve; `myMembership` is what tells the UI
                // what actually happened.
                AppLogger.store.error("[ParticipantStore] Roster listener failed: \(error.localizedDescription)")
                return
            }

            self.allParticipants = Self.sorted(snapshot?.documents.compactMap { try? $0.data(as: Participant.self) } ?? [])
        }
    }

    /// Survives removal, which is the entire point. `allow get` on your own
    /// document has no status condition, so this keeps delivering after the
    /// roster query starts failing.
    private func startSelfListener() {
        guard selfListener == nil, let uid = Auth.auth().currentUser?.uid else { return }

        selfListener = participantsRef.document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    AppLogger.store.error("[ParticipantStore] Self listener failed: \(error.localizedDescription)")
                    return
                }

                guard let snapshot, snapshot.exists else {
                    // Document genuinely gone: never joined, or the trip was
                    // purged. Distinct from a permission error above.
                    self.myMembership = nil
                    self.hasLoaded = true
                    return
                }

                self.myMembership = try? snapshot.data(as: Participant.self)
                self.hasLoaded = true
            }
    }

    func stop() {
        AppLogger.store.info("[ParticipantStore] Stopped listening to participants in trip: \(self.tripId)")
        rosterListener?.remove()
        rosterListener = nil
        selfListener?.remove()
        selfListener = nil
    }

    // MARK: - Ingest

    /// Captains first, then longest-standing, then by name. The name tiebreaker
    /// isn't decoration: a batch write stamps several documents with the same
    /// `joinedAt`, and without a total order rows visibly swap places on every
    /// snapshot.
    private static func sorted(_ members: [Participant]) -> [Participant] {
        members.sorted { a, b in
            if a.role.rank != b.role.rank { return a.role.rank > b.role.rank }
            if a.joinedAt != b.joinedAt { return a.joinedAt < b.joinedAt }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }
}

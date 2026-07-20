import FirebaseAuth
import FirebaseFirestore
import Foundation

@Observable
final class TripManager {
    // MARK: - Published State
    var currentTrip: Trip? = nil
    var currentParticipant: Participant? = nil

    // MARK: - Dependencies
    let tripId: String

    // MARK: - Computed Vars
    var inviteToken: String {
        return currentTrip?.inviteToken ?? ""
    }

    var currentUserRole: ParticipantRole? {
        currentParticipant?.role
    }

    var currentUserIsKicked: Bool {
        currentParticipant?.status == .kicked
    }

    /// True once we've confirmed the user is an active participant of this trip.
    var isActiveParticipant: Bool {
        currentParticipant != nil && !currentUserIsKicked
    }

    // MARK: - Firestore Listeners
    private var tripListener: ListenerRegistration?
    private var participantListener: ListenerRegistration?

    // MARK: - Error / Removal signals
    var showError: Bool = false
    /// Flips true when the user is no longer an active participant (kicked or
    /// their participant doc vanished). Drive an ejection alert off this.
    var wasRemoved: Bool = false
    /// True if we have successfully loaded the trip at least once.
    var hasLoadedOnce: Bool = false

    // MARK: - Initialization
    init(tripId: String) {
        self.tripId = tripId
    }

    deinit {
        stopListening()
    }

    var dateRangeString: String {
        guard let start = currentTrip?.startDate, let end = currentTrip?.endDate else { return "" }
        return "\(start.displayStringUTC) - \(end.displayStringUTC)"
    }

    // MARK: - Lifecycle Management
    func startListening() {
        guard !tripId.isEmpty else { return }

        startTripListener()
        startParticipantListener()
    }

    private func startTripListener() {
        guard tripListener == nil else { return }

        AppLogger.managers.info("[TripManager.swift] Started listening for trip document: \(tripId)")

        tripListener = Firestore.firestore()
            .collection("trips")
            .document(tripId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    AppLogger.managers.error("[TripManager.swift] Trip listener error: \(error.localizedDescription)")
                    self.showError = true
                    return
                }

                guard let doc = snapshot else { return }

                // Trip deleted out from under us.
                guard doc.exists else {
                    self.currentTrip = nil
                    return
                }

                do {
                    self.currentTrip = try doc.data(as: Trip.self)
                    self.hasLoadedOnce = true
                } catch {
                    AppLogger.managers.error("[TripManager.swift] Trip decode failed: \(error.localizedDescription)")
                    self.showError = true
                }
            }
    }

    private func startParticipantListener() {
        guard participantListener == nil else { return }

        guard let uid = Auth.auth().currentUser?.uid else {
            AppLogger.managers.error("[TripManager.swift] No authenticated user; cannot listen to participant doc.")
            return
        }

        AppLogger.managers.info("[TripManager.swift] Started listening for own participant doc in trip: \(tripId)")

        participantListener = Firestore.firestore()
            .collection("trips")
            .document(tripId)
            .collection("participants")
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    // A permission-denied here typically means you're no longer an
                    // active participant (rules gate reads on active membership).
                    AppLogger.managers.error("[TripManager.swift] Participant listener error: \(error.localizedDescription)")
                    self.currentParticipant = nil
                    self.wasRemoved = true
                    return
                }

                guard let snapshot, snapshot.exists else {
                    // Participant doc gone → you left or were removed.
                    self.currentParticipant = nil
                    self.wasRemoved = true
                    return
                }

                do {
                    let participant = try snapshot.data(as: Participant.self)
                    self.currentParticipant = participant
                    // If the doc is readable and shows kicked, treat as removed too.
                    if participant.status == .kicked {
                        self.wasRemoved = true
                    }
                } catch {
                    AppLogger.managers.error("[TripManager.swift] Participant decode failed: \(error.localizedDescription)")
                }
            }
    }

    func stopListening() {
        tripListener?.remove()
        tripListener = nil
        participantListener?.remove()
        participantListener = nil
    }
}

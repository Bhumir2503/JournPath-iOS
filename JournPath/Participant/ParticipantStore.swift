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
    var participants: [Participant] = []
    var kickedParticipants: [Participant] = []

    // MARK: - Computed Vars
    var selfParticipant: Participant? {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return nil }
        return participants.first(where: { $0.id == currentUserId })
    }
    var isCaptain: Bool {
        return selfParticipant?.role == .captain
    }

    var role: ParticipantRole {
        return selfParticipant?.role ?? .passenger
    }

    var isKicked: Bool {
        return selfParticipant?.status == .kicked
    }

    var sortedParticipants: [Participant] {
        return participants.sorted { p1, p2 in
            if p1.role == .captain && p2.role != .captain {
                return true
            } else if p1.role != .captain && p2.role == .captain {
                return false
            }
            return p1.joinedAt < p2.joinedAt
        }
    }

    // MARK: - Firestore Listeners
    private var activeListener: ListenerRegistration?
    private var kickedListener: ListenerRegistration?

    init(tripId: String) {
        self.tripId = tripId
    }

    deinit {
        stop()
    }

    func start() {
        guard !tripId.isEmpty else { return }
        guard activeListener == nil else { return }

        AppLogger.managers.info("[ParticipantManager.swift] Started listening for active Participant Collection in trip document: \(tripId)")

        activeListener = Firestore.firestore()
            .collection("trips")
            .document(tripId)
            .collection("participants")
            .whereField("status", isEqualTo: "accepted")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if error != nil {
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.participants = documents.compactMap { doc in
                    do {
                        return try doc.data(as: Participant.self)
                    } catch {
                        return nil
                    }
                }
            }
    }

    private func checkAndListenToKicked() {

    }

    func stop() {
        AppLogger.managers.info("[ParticipantStore.swift] Stopped listening for active Participant Collection in trip document: \(tripId)")
        activeListener?.remove()
        activeListener = nil
        kickedListener?.remove()
        kickedListener = nil
    }

    func canKick(participant: Participant) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid,
            let currentUserRole = participants.first(where: { $0.id == currentUserId })?.role,
            let targetId = participant.id,
            targetId != currentUserId
        else {
            return false
        }

        switch currentUserRole {
        case .captain:
            return participant.role != .captain
        case .passenger, .observer:
            return false
        }
    }

    func canChangeRole(of participant: Participant) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid,
            let currentUserRole = participants.first(where: { $0.id == currentUserId })?.role,
            let targetId = participant.id,
            targetId != currentUserId
        else {
            return false
        }
        return currentUserRole.rank > participant.role.rank
    }

    func assignableRoles(for participant: Participant) -> [ParticipantRole] {
        guard let currentUserId = Auth.auth().currentUser?.uid,
            let currentUserRole = participants.first(where: { $0.id == currentUserId })?.role
        else {
            return []
        }

        if currentUserRole == .captain {
            return [.captain, .passenger, .observer]
        }

        return ParticipantRole.allCases.filter { role in
            role.rank < currentUserRole.rank
        }
    }
}

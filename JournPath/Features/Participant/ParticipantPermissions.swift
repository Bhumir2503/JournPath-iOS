import Foundation

/// Pure policy. Every rule here has a twin in firestore.rules — write the rules
/// *from* this file so the two can't drift. A client-side check is a UI
/// affordance, not enforcement: the rules are what actually stops a kick.
///
/// No dependencies, nothing worth faking: caseless enum.
enum ParticipantPermissions {

    // MARK: Trip content

    static func canEditTrip(_ actor: Participant?) -> Bool {
        guard let actor, actor.status.isActive else { return false }
        return actor.role == .captain || actor.role == .passenger
    }

    static func canDeleteTrip(_ actor: Participant?) -> Bool {
        guard let actor, actor.status.isActive else { return false }
        return actor.role == .captain
    }

    // MARK: Crew

    static func canInvite(_ actor: Participant?) -> Bool {
        guard let actor, actor.status.isActive else { return false }
        return actor.role == .captain || actor.role == .passenger
    }

    /// Removing someone else. Leaving is `canLeave` — a captain who wants out
    /// takes a different path, so this deliberately returns false for self.
    static func canKick(_ target: Participant, by actor: Participant?) -> Bool {
        guard let actor, actor.status.isActive, actor.role == .captain else { return false }
        guard target.id != actor.id else { return false }  // that's leaving
        guard !target.status.isGone else { return false }  // already out
        return target.role != .captain  // captains are peers
    }

    /// Putting someone back. Capacity is deliberately *not* checked here — two
    /// captains can restore simultaneously into the last seat, so the callable
    /// owns that check and returns `trip_full`. The client just shows the error.
    static func canRestore(_ target: Participant, by actor: Participant?) -> Bool {
        guard let actor, actor.status.isActive, actor.role == .captain else { return false }
        return target.status == .kicked
    }

    static func canChangeRole(
        of target: Participant, to newRole: ParticipantRole,
        by actor: Participant?,
        in roster: [Participant]
    ) -> Bool {
        guard let actor, actor.status.isActive, actor.role == .captain else { return false }
        guard !target.status.isGone, target.role != newRole else { return false }
        // Demoting the last captain would leave the trip unmanageable.
        if target.role == .captain, newRole != .captain {
            return captainCount(in: roster) > 1
        }
        return true
    }

    // MARK: Helpers
    static func captainCount(in roster: [Participant]) -> Int {
        roster.filter { $0.status.isActive && $0.role == .captain }.count
    }
}

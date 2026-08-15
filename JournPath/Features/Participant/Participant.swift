import FirebaseFirestore
import Foundation

enum ParticipantRole: String, Codable, CaseIterable {
    case captain
    case passenger
    case observer

    var rank: Int {
        switch self {
        case .captain: return 2
        case .passenger: return 1
        case .observer: return 0
        }
    }

    var description: String {
        switch self {
        case .captain:
            return "The owner of the trip. Has full access to manage all participants, settings, and trip content."
        case .passenger:
            return "Active trip collaborator. Can view, edit, and add trip content (itinerary, budget, etc.)."
        case .observer:
            return "Read-only trip member. Can view trip details but cannot make edits."
        }
    }
}

enum ParticipantStatus: String, Codable {
    case invited
    case accepted
    case declined
    case left
    case kicked
}

struct Participant: Codable, Identifiable, Equatable {
    @DocumentID var id: String?

    let role: ParticipantRole
    let displayName: String
    let photoURL: String?
    let status: ParticipantStatus
    let joinedAt: Date

    var photo: URL? {
        photoURL.flatMap(URL.init(string:))
    }

    var initials: String {
        let letters =
            displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

extension ParticipantStatus {

    var isActive: Bool { self == .accepted }

    var isGone: Bool {
        switch self {
        case .declined, .left, .kicked: true
        case .invited, .accepted: false
        }
    }

    var badgeText: String? {
        switch self {
        case .accepted: nil
        case .invited: "Pending"
        case .declined: "Declined"
        case .left: "Left"
        case .kicked: "Removed"
        }
    }

    var subtitle: String? {
        switch self {
        case .accepted: nil
        case .invited: "Invitation sent"
        case .declined: "Declined the invitation"
        case .left: "Left the trip"
        case .kicked: "Kicked from the trip"
        }
    }
}
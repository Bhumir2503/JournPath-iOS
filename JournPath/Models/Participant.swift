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
    case banned
}

struct Participant: Codable, Identifiable {
    var id: String { userId ?? "" }

    @DocumentID var userId: String?

    let role: ParticipantRole
    let displayName: String
    let photoURL: String?
    let status: ParticipantStatus
    let emergencyContactName: String?
    let emergencyContactPhone: String?
    let joinedAt: Date
    var isKicked: Bool?

    enum CodingKeys: String, CodingKey {
        case userId
        case role
        case displayName
        case photoURL
        case status
        case emergencyContactName
        case emergencyContactPhone
        case joinedAt
        case isKicked
    }
}

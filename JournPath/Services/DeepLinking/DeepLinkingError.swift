import Foundation

enum DeepLinkError: LocalizedError {
    case tripIsFull
    case invalidInviteLink
    case tripDeleted
    case userKicked

    var errorDescription: String? {
        switch self {
        case .tripIsFull:
            return "This trip has reached its maximum capacity. The trip must be upgraded to add more passengers."
        case .invalidInviteLink:
            return "This invite link is invalid or has expired."
        case .tripDeleted:
            return "This trip no longer exists."
        case .userKicked:
            return "You have been removed from this trip by the owner and cannot rejoin."
        }
    }
}

import Foundation

enum DashboardAlert: Identifiable, Hashable {
    case rename, leave
    case error(String)
    case tripDeleted
    case removed
    case upgraded
    
    var id: Int { hashValue }
    
    var title: String {
        switch self {
        case .leave: return "Leave Trip?"
        case .rename: return "Rename Trip"
        case .tripDeleted: return "Trip Deleted"
        case .upgraded: return "Premium Access Unlocked!"
        case .removed: return "Removed From Trip"
        case .error(_): return "Error"
        }
    }
    
    var message: String? {
        switch self {
        case .leave: return "Are you sure you want to leave this trip?"
        case .error(let msg): return msg
        case .tripDeleted: return "This trip has been deleted and is no longer available."
        case .upgraded: return "You now have access to premium features!"
        case .removed: return "You've been removed from this trip and no longer have access."
        case .rename: return nil
        }
    }
}

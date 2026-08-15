import Foundation

/// UI-facing split mode. Its raw values are the segmented-control labels.
enum SplitType: String, CaseIterable, Identifiable, Codable {
    case evenly = "Evenly"
    case manually = "Manually"
    case percentage = "Percentage"
    var id: String { rawValue }
}

/// Wire-facing split mode. Stored on the Firestore document.
enum SplitTypeWire: String, Codable {
    case equal, manual, percentage
}

extension SplitType {
    var wire: SplitTypeWire {
        switch self {
        case .evenly: return .equal
        case .manually: return .manual
        case .percentage: return .percentage
        }
    }
}

extension SplitTypeWire {
    var ui: SplitType {
        switch self {
        case .equal: return .evenly
        case .manual: return .manually
        case .percentage: return .percentage
        }
    }
}

enum RateStatus: String, Codable {
    case pending, final
}

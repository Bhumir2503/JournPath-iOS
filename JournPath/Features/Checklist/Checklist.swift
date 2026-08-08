import FirebaseFirestore
import Foundation

// MARK: - Kind

/// Determines how `ChecklistItem.checkedBy` is interpreted.
///
/// - `shared`:   one tent, somebody brings it. Done when ANYONE has checked it.
/// - `personal`: everyone needs their own passport. Done when YOU have checked it.
///
/// This is the only thing that differs between the two list types — the item
/// document shape is identical, which is why adding personal lists later
/// requires no migration.
enum ChecklistKind: String, Codable, Hashable, CaseIterable {
    case shared
    case personal
}

// MARK: - Checklist

struct Checklist: Identifiable, Codable, Hashable {
    @DocumentID var id: String?

    var title: String
    var kind: ChecklistKind
    var icon: String?

    /// Fractional ordering. See `ChecklistPosition`.
    var sortIndex: Double

    var createdBy: String
    @ServerTimestamp var createdAt: Timestamp?
    var clientCreatedAt: Timestamp

    @ServerTimestamp var updatedAt: Timestamp?

    var version: Int
}

// MARK: - ChecklistItem

struct ChecklistItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String?

    var title: String
    var note: String?
    var quantity: Int?

    /// Who is responsible for bringing it. Deliberately separate from
    /// `checkedBy` — assignment is a plan, checking is a fact.
    var assignedTo: String?

    var position: Double

    /// Denormalized from the parent list so security rules can read it without
    /// a `get()` on the parent — that would be a billed read on every single
    /// checkbox tap. Cost: flipping a list's kind means rewriting its items.
    var listKind: ChecklistKind

    /// uid -> when they checked it.
    ///
    /// A map rather than `isDone: Bool` because Firestore merges dotted field
    /// paths per-key. Two people checking two different items while offline
    /// both replay without clobbering each other. A boolean is a whole-document
    /// write and one of those toggles would silently vanish.
    var checkedBy: [String: Timestamp]

    var createdBy: String
    @ServerTimestamp var createdAt: Timestamp?
    var clientCreatedAt: Timestamp
    @ServerTimestamp var updatedAt: Timestamp?

    var version: Int
}

extension ChecklistItem {

    /// Has anyone at all checked this?
    var isCheckedByAnyone: Bool { !checkedBy.isEmpty }

    func isChecked(by uid: String) -> Bool { checkedBy[uid] != nil }

    /// The one the UI should actually call. Resolves `listKind` for you.
    func isDone(for uid: String) -> Bool {
        switch listKind {
        case .shared: return isCheckedByAnyone
        case .personal: return isChecked(by: uid)
        }
    }

    /// Everyone who has checked it, most recent first. Drives the
    /// "Bhumi packed this" attribution row on shared lists.
    var checkers: [(uid: String, at: Date)] {
        checkedBy
            .map { (uid: $0.key, at: $0.value.dateValue()) }
            .sorted { $0.at > $1.at }
    }
}

// MARK: - Positioning

/// Fractional indexing. Inserting between two items is one write instead of
/// rewriting the whole list, which is what makes reordering survive offline
/// without clobbering anyone else's reorder.
enum ChecklistPosition {

    /// Gap between adjacent items. Large enough that you can subdivide ~50
    /// times before running out of Double precision.
    static let spacing: Double = 1024

    /// Position for an item dropped between `prev` and `next`.
    /// Pass nil for either end of the list.
    static func between(_ prev: Double?, _ next: Double?) -> Double {
        switch (prev, next) {
        case (let p?, let n?): return (p + n) / 2
        case (let p?, nil): return p + spacing
        case (nil, let n?): return n - spacing
        case (nil, nil): return spacing
        }
    }

    /// Below this, repeated midpoint splits start losing precision and two
    /// items can collapse onto the same Double. Callers renormalize instead.
    static let minimumGap: Double = 0.0001

    static func needsRenormalization(_ prev: Double?, _ next: Double?) -> Bool {
        guard let prev, let next else { return false }
        return abs(next - prev) < minimumGap
    }

    /// Clean positions for a whole list, used when renormalizing.
    static func normalized(count: Int) -> [Double] {
        (1...max(count, 1)).map { Double($0) * spacing }
    }
}

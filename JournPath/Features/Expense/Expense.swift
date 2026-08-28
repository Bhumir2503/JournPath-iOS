import FirebaseFirestore
import SwiftUI

// MARK: - Split type

/// Raw values are the wire format and **must match the server's `SplitType`**
/// in `splits.js` exactly. Display strings live in `displayName` so renaming a
/// label can never change what's written to Firestore.
enum SplitType: String, Codable, CaseIterable, Identifiable, Hashable {
    case equal
    case exact
    case percentage

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .equal: return "Evenly"
        case .exact: return "Exact"
        case .percentage: return "Percentage"
        }
    }
}

// MARK: - Rate status

/// Server-owned. The client only reads this to decide what the row looks like.
enum RateStatus: String, Codable, Hashable {
    /// Awaiting conversion — no rate table covered `spentAt` yet. Resolves itself.
    case pending
    /// Converted. Counts toward balances.
    case final
    /// Conversion failed in a way retrying won't fix. Needs a human.
    case failed
}

// MARK: - Category

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case foodDrink = "food_drink"
    case travel
    case lodging
    case artsCulture = "arts_culture"
    case entertainment
    case recreation
    case sports
    case waterSports = "water_sports"
    case education
    case health
    case shopping
    case other
    case journpath

    static var userSelectable: [ExpenseCategory] {
        allCases.filter { $0 != .journpath }
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .foodDrink: return "Food & Drink"
        case .travel: return "Travel"
        case .lodging: return "Lodging"
        case .artsCulture: return "Arts & Culture"
        case .entertainment: return "Entertainment"
        case .recreation: return "Recreation"
        case .sports: return "Sports"
        case .waterSports: return "Water Sports"
        case .education: return "Education"
        case .health: return "Health"
        case .shopping: return "Shopping"
        case .other: return "Other"
        case .journpath: return "JournPath"
        }
    }

    var icon: String {
        switch self {
        case .foodDrink: return "fork.knife"
        case .travel: return "airplane"
        case .lodging: return "bed.double.fill"
        case .artsCulture: return "building.columns.fill"
        case .entertainment: return "ticket.fill"
        case .recreation: return "tree.fill"
        case .sports: return "sportscourt.fill"
        case .waterSports: return "figure.pool.swim"
        case .education: return "books.vertical.fill"
        case .health: return "cross.case.fill"
        case .shopping: return "bag.fill"
        case .other: return "ellipsis"
        case .journpath: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .foodDrink: return .orange
        case .travel: return .blue
        case .lodging: return .mint
        case .artsCulture: return .purple
        case .entertainment: return .pink
        case .recreation: return .green
        case .sports: return .indigo
        case .waterSports: return .cyan
        case .education: return .brown
        case .health: return .red
        case .shopping: return .teal
        case .other: return .gray
        case .journpath: return .yellow
        }
    }
}

// MARK: - Expense

struct Expense: Identifiable, Codable, Hashable {
    @DocumentID var id: String?

    var activityId: String?
    var title: String
    var notes: String?
    var category: ExpenseCategory?
    var paidBy: String

    // MARK: Money — client owned

    var amountMinor: Int
    var currency: String
    var currencyExponent: Int
    /// Date of *spending*, not of logging. Drives the rate lookup, so a receipt
    /// entered three days late still converts at the rate from the day you paid.
    var spentAt: Timestamp

    // MARK: Split — client owned

    var splitType: SplitType
    /// uid -> minor units, in the expense's own currency.
    /// A map, not an array: Firestore merges dotted paths per key, so two people
    /// editing different shares don't clobber each other.
    var splits: [String: Int]
    var equalParticipants: [String]?
    /// Basis points. 2550 = 25.5%. Integers because 33.33 × 3 ≠ 100.
    var splitPercentsBp: [String: Int]?

    // MARK: Server owned — the client never writes these

    var baseAmountMinor: Int?
    var baseSplits: [String: Int]?
    var rateUsed: Double?
    /// Points at the whole day's rate table actually used, after any weekend
    /// walk-back — not the requested date.
    var rateDocId: String?
    var rateStatus: RateStatus?
    var needsReview: Bool?

    // MARK: Metadata

    var createdBy: String
    @ServerTimestamp var createdAt: Timestamp?
    var clientCreatedAt: Timestamp
    @ServerTimestamp var updatedAt: Timestamp?
    /// Optimistic-concurrency counter. Rules require an incoming write to carry
    /// exactly `version + 1`, so an offline edit built on a stale read is
    /// rejected rather than silently overwriting a newer one.
    var version: Int

    // MARK: - Derived

    /// Server fields are absent until the trigger has run, so treat missing as pending.
    var effectiveRateStatus: RateStatus { rateStatus ?? .pending }
    var isFlagged: Bool { needsReview == true }

    /// Whether this expense currently counts toward balances.
    var countsTowardLedger: Bool {
        effectiveRateStatus == .final && !isFlagged && baseAmountMinor != nil
    }

    /// True when the row should skip the "≈ $161.99" secondary line.
    func isBaseCurrency(_ baseCurrency: String) -> Bool {
        currency == baseCurrency
    }

    /// What this expense did to one person's balance, in base minor units.
    /// Nil until the server has converted it.
    func netEffect(for uid: String) -> Int? {
        guard let baseAmountMinor, let baseSplits else { return nil }
        let paid = (paidBy == uid) ? baseAmountMinor : 0
        let owed = baseSplits[uid] ?? 0
        return paid - owed
    }
}

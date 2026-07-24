import FirebaseFirestore
import Foundation


// =============================================================================
// MARK: - Wire structs (nested inside Expense)
// =============================================================================

struct SplitShare: Codable, Equatable, Hashable {
    let amountMinor: Int
}

struct BaseSplitShare: Codable, Equatable, Hashable {
    let baseAmountMinor: Int
}

struct ExpenseGuestDoc: Codable, Equatable, Hashable {
    let id: String
    let name: String

    init(from guest: ExpenseGuest) {
        self.id = guest.id
        self.name = guest.name
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// =============================================================================
// MARK: - Expense (Firestore document)
// =============================================================================

/// One-to-one mirror of `trips/{tripId}/expenses/{expenseId}`. Written by the
/// client via `TripRepository`; conversion fields written only by the Cloud
/// Function. `isPendingSync` is transient view state, populated from
/// `DocumentSnapshot.metadata.hasPendingWrites` — not encoded.
struct Expense: Codable, Identifiable, Equatable, Hashable {

    @DocumentID var id: String?

    // ---- Identity & linkage ----
    var activityId: String?
    var title: String

    // ---- Money (client-owned) ----
    var amountMinor: Int
    var currency: String
    var currencyExponent: Int
    var paidBy: String

    // ---- Split (client-owned) ----
    var splitEnabled: Bool
    var splitType: SplitTypeWire
    var splits: [String: SplitShare]
    var excludedFromEqualSplit: [String]?
    var splitPercentsBp: [String: Int]?
    var guests: [ExpenseGuestDoc]

    // ---- Conversion (server-owned; nil until rateStatus == .final) ----
    var baseCurrency: String?
    var baseAmountMinor: Int?
    var rateUsed: Double?
    var rateDate: String?
    var baseSplits: [String: BaseSplitShare]?
    var rateStatus: RateStatus
    var needsReview: Bool

    // ---- Lifecycle ----
    var createdBy: String
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?
    var clientCreatedAt: String
    var version: Int
    var deletedAt: Timestamp?

    // ---- Optional ----
    var notes: String?
    var attachmentRefs: [String]

    // ---- Transient view state (not encoded) ----
    var isPendingSync: Bool = false

    // MARK: Derived helpers (not persisted)

    /// Payer's share, computed from the invariant.
    var payerShareMinor: Int {
        amountMinor - splits.values.reduce(0) { $0 + $1.amountMinor }
    }

    var payerBaseShareMinor: Int? {
        guard let base = baseAmountMinor, let baseSplits else { return nil }
        return base - baseSplits.values.reduce(0) { $0 + $1.baseAmountMinor }
    }

    var isConverting: Bool { rateStatus == .pending }

    private enum CodingKeys: String, CodingKey {
        case id, activityId, title
        case amountMinor, currency, currencyExponent, paidBy
        case splitEnabled, splitType, splits
        case excludedFromEqualSplit, splitPercentsBp, guests
        case baseCurrency, baseAmountMinor, rateUsed, rateDate, baseSplits
        case rateStatus, needsReview
        case createdBy, createdAt, updatedAt, clientCreatedAt, version, deletedAt
        case notes, attachmentRefs
        // isPendingSync is intentionally omitted from coding
    }
}

// =============================================================================
// MARK: - Bridge: CostInfo → Expense (for saves)
// =============================================================================

enum ExpenseBridgeError: LocalizedError {
    case missingTotal
    case missingPayer
    case zeroAmount
    case splitsExceedTotal(overByMinor: Int)

    var errorDescription: String? {
        switch self {
        case .missingTotal: return "Enter an amount first."
        case .missingPayer: return "Select who paid."
        case .zeroAmount: return "Amount must be greater than zero."
        case .splitsExceedTotal(let over): return "Assigned shares exceed the total by \(over) minor units."
        }
    }
}

extension Expense {

    /// Build an `Expense` document from editor state. Server-owned fields are
    /// left nil / defaulted — the Cloud Function fills them on sync.
    ///
    /// This is the SINGLE point where UI Doubles become wire integers. From
    /// here on, nothing in the pipeline touches Double for money.
    init(
        from cost: CostInfo,
        activityId: String?,
        title: String,
        createdBy uid: String,
        clientCreatedAt: Date = Date()
    ) throws {
        guard let total = cost.totalAmount else { throw ExpenseBridgeError.missingTotal }
        guard let payer = cost.paidByParticipantId else { throw ExpenseBridgeError.missingPayer }

        let code = cost.currencyCode.uppercased()
        let digits = CurrencyInfo.fractionDigits(for: code)
        let amountMinor = CurrencyInfo.minorUnits(total, code: code)
        guard amountMinor > 0 else { throw ExpenseBridgeError.zeroAmount }

        // Non-payer shares only. Payer's share stays derived.
        var splits: [String: SplitShare] = [:]
        var assigned = 0
        if cost.isSplitEnabled {
            for (memberId, amount) in cost.participantAmounts where memberId != payer {
                let minor = CurrencyInfo.minorUnits(amount, code: code)
                guard minor > 0 else { continue }
                splits[memberId] = SplitShare(amountMinor: minor)
                assigned += minor
            }
            if assigned > amountMinor {
                throw ExpenseBridgeError.splitsExceedTotal(overByMinor: assigned - amountMinor)
            }
        }

        // Only the intent field matching the active mode is populated.
        var excluded: [String]? = nil
        var percentBp: [String: Int]? = nil
        if cost.isSplitEnabled {
            switch cost.splitType {
            case .evenly:
                excluded = Array(cost.excludedFromEqualSplit)
            case .percentage:
                var bp: [String: Int] = [:]
                for (memberId, pct) in cost.participantPercentages {
                    let points = Int((pct * 100).rounded())
                    guard points > 0 else { continue }
                    bp[memberId] = points
                }
                percentBp = bp
            case .manually:
                break
            }
        }

        self.id = nil
        self.activityId = activityId
        self.title = title
        self.amountMinor = amountMinor
        self.currency = code
        self.currencyExponent = digits
        self.paidBy = payer
        self.splitEnabled = cost.isSplitEnabled
        self.splitType = cost.splitType.wire
        self.splits = splits
        self.excludedFromEqualSplit = excluded
        self.splitPercentsBp = percentBp
        self.guests = cost.guests.map { ExpenseGuestDoc(from: $0) }
        self.baseCurrency = nil
        self.baseAmountMinor = nil
        self.rateUsed = nil
        self.rateDate = nil
        self.baseSplits = nil
        self.rateStatus = .pending
        self.needsReview = false
        self.createdBy = uid
        self.createdAt = nil  // filled by @ServerTimestamp on write
        self.updatedAt = nil
        self.clientCreatedAt = ISO8601DateFormatter().string(from: clientCreatedAt)
        self.version = 1
        self.deletedAt = nil
        self.notes = nil
        self.attachmentRefs = []
        self.isPendingSync = false
    }
}

// =============================================================================
// MARK: - Bridge: Expense → CostInfo (for edits)
// =============================================================================

extension CostInfo {

    /// Rebuild editor state from a persisted expense so the CostCard can
    /// reopen it. Materializes minor-unit shares back into Doubles for
    /// display, and restores whichever mode intent field is populated.
    init(from expense: Expense) {
        let digits = CurrencyInfo.fractionDigits(for: expense.currency)
        let toDouble = { (minor: Int) -> Double in
            SplitMath.toDisplay(minor, fractionDigits: digits)
        }

        var amounts: [String: Double] = [:]
        for (id, share) in expense.splits {
            amounts[id] = toDouble(share.amountMinor)
        }
        // Payer's derived share, materialized for display.
        let payerShare = expense.payerShareMinor
        if payerShare > 0 {
            amounts[expense.paidBy] = toDouble(payerShare)
        }

        var percentages: [String: Double] = [:]
        if let bp = expense.splitPercentsBp {
            for (id, points) in bp {
                percentages[id] = Double(points) / 100.0
            }
        }

        self.currencyCode = expense.currency
        self.isSplitEnabled = expense.splitEnabled
        self.participantAmounts = amounts
        self.totalAmount = toDouble(expense.amountMinor)
        self.splitType = expense.splitType.ui
        self.participantPercentages = percentages
        self.excludedFromEqualSplit = Set(expense.excludedFromEqualSplit ?? [])
        self.paidByParticipantId = expense.paidBy
        self.guests = expense.guests.map { ExpenseGuest(id: $0.id, name: $0.name) }
        self.guestNameCounter = expense.guests.count
    }
}

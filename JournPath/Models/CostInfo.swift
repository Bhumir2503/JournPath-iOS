import Foundation

struct ExpenseGuest: Identifiable, Equatable, Codable {
    let id: String
    var name: String
}

/// Editor state for the CostCard. Holds Doubles because SwiftUI text fields
/// produce them; every value crosses to integer minor units at the wire edge
/// via `Expense(costInfo:...)` and never as a Double again.
///
/// This is NOT what Firestore stores. See `Expense` for that.
struct CostInfo: Equatable, Codable {
    var currencyCode: String = "USD"
    var isSplitEnabled = false
    var participantAmounts: [String: Double] = [:]
    var totalAmount: Double?
    var splitType: SplitType = .evenly
    var participantPercentages: [String: Double] = [:]
    var excludedFromEqualSplit: Set<String> = []
    var paidByParticipantId: String?
    var guests: [ExpenseGuest] = []

    /// Monotonic counter so re-added guests never reuse a default name.
    var guestNameCounter: Int = 0
}

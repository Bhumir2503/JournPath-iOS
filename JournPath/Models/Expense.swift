import Foundation

enum SplitType: String, CaseIterable, Identifiable, Codable {
    case evenly = "Evenly"
    case manually = "Manually"
    case percentage = "Percentage"
    var id: String { rawValue }
}

struct ExpenseGuest: Identifiable, Equatable, Codable {
    let id: String
    var name: String
}

struct Expense: Equatable, Codable {
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

// MARK: - Split math (single source of truth for the remainder rule)

/// All split arithmetic happens in integer minor units so client display,
/// `expenseFields()` serialization, and the Cloud Function's validation
/// produce bit-identical numbers. Doubles exist only at the display edge.
enum SplitMath {

    /// Deterministic remainder recipient: the payer absorbs leftover minor
    /// units; if the payer isn't participating, the first sorted ID does.
    /// This MUST match the server's derivation rule.
    static func remainderRecipient(includedIDs: [String], payerId: String?) -> String? {
        guard !includedIDs.isEmpty else { return nil }
        if let payerId, includedIDs.contains(payerId) { return payerId }
        return includedIDs.sorted()[0]
    }

    /// Equal split in minor units. Returns [id: minorUnits].
    static func equalShares(totalMinor: Int, includedIDs: [String], payerId: String?) -> [String: Int] {
        guard !includedIDs.isEmpty, totalMinor > 0 else { return [:] }
        let n = includedIDs.count
        let base = totalMinor / n
        let remainder = totalMinor % n
        let recipient = remainderRecipient(includedIDs: includedIDs, payerId: payerId)

        var shares: [String: Int] = [:]
        for id in includedIDs {
            shares[id] = base + (id == recipient ? remainder : 0)
        }
        return shares
    }

    /// Percentage split in minor units. Percentages arrive as Doubles from
    /// the UI, are snapped to integer basis points (33.33% -> 3333), and all
    /// share math is integer. Rounding dust goes to the remainder recipient
    /// only when the percentages fully account for 100%.
    static func percentageShares(
        totalMinor: Int,
        percentages: [String: Double],
        orderedIDs: [String],
        payerId: String?
    ) -> [String: Int] {
        guard totalMinor > 0 else { return [:] }

        var basisPoints: [String: Int] = [:]
        for id in orderedIDs {
            guard let pct = percentages[id] else { continue }
            let bp = Int((pct * 100).rounded())
            guard bp > 0 else { continue }
            basisPoints[id] = bp
        }
        guard !basisPoints.isEmpty else { return [:] }

        var shares: [String: Int] = [:]
        var assigned = 0
        for (id, bp) in basisPoints {
            let share = totalMinor * bp / 10_000  // integer math, truncates
            shares[id] = share
            assigned += share
        }

        // Exact check, no float epsilon: dust is only distributed when the
        // user has assigned exactly 100%.
        let totalBp = basisPoints.values.reduce(0, +)
        if totalBp == 10_000 {
            let dust = totalMinor - assigned
            if dust != 0,
                let recipient = remainderRecipient(includedIDs: Array(basisPoints.keys), payerId: payerId)
            {
                shares[recipient, default: 0] += dust
            }
        }
        return shares
    }

    /// Display-edge conversion. The resulting Double may carry float
    /// representation error, but it is < half a minor unit, so formatting
    /// and round-tripping back through `CurrencyInfo.minorUnits` are exact.
    static func toDisplay(_ minor: Int, fractionDigits: Int) -> Double {
        Double(minor) / pow(10.0, Double(fractionDigits))
    }
}

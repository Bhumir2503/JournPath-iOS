import Foundation

/// Split math. **Must behave identically to `splits.js` on the server.**
///
/// The client computes `splits` for the live form preview; the server computes
/// `baseSplits` for the ledger. Different fields, so no write conflict — but if
/// the rounding diverges by a single minor unit, the preview disagrees with the
/// stored result and the server flags the expense for review.
///
/// If you change a rule here, change it there in the same commit.
enum ExpenseSplitMath {

    enum SplitError: LocalizedError {
        case noParticipants
        case badBasisPoints(uid: String)
        case percentagesDontTotal(Int)

        var errorDescription: String? {
            switch self {
            case .noParticipants:
                return "A split needs at least one participant."
            case .badBasisPoints(let uid):
                return "Invalid percentage for participant \(uid)."
            case .percentagesDontTotal(let bp):
                let percent = Double(bp) / 100
                return "Percentages must total 100% (currently \(percent.formatted())%)."
            }
        }
    }

    // MARK: - Remainder rule

    /// Who absorbs a rounding remainder: the payer, or — if the payer isn't in
    /// the split — the first participant by sorted uid.
    ///
    /// Arbitrary, but determinism is the only property that matters. The server
    /// uses the same rule for the same reason.
    static func absorber(in splits: [String: Int], paidBy: String) -> String? {
        if splits[paidBy] != nil { return paidBy }
        return splits.keys.sorted().first
    }

    // MARK: - Equal

    /// Integer divide, remainder to the payer.
    ///
    /// The remainder is at most n-1 minor units, but it has to land somewhere
    /// predictable — if client and server hand it to different people, balances
    /// stop reconciling.
    static func equalSplits(
        amountMinor: Int,
        participants: [String],
        paidBy: String
    ) throws -> [String: Int] {
        let uids = Array(Set(participants.filter { !$0.isEmpty })).sorted()
        guard !uids.isEmpty else { throw SplitError.noParticipants }

        // Swift's `/` truncates toward zero, matching JS `Math.trunc`.
        let base = amountMinor / uids.count

        var splits = [String: Int]()
        for uid in uids { splits[uid] = base }

        let remainder = amountMinor - (base * uids.count)
        if remainder != 0, let absorber = absorber(in: splits, paidBy: paidBy) {
            splits[absorber, default: 0] += remainder
        }

        return splits
    }

    // MARK: - Percentage

    /// Basis points to minor units, truncated per person, accumulated rounding
    /// loss to the payer.
    ///
    /// Basis points because 33.33 × 3 never equals 100 in floating point, and a
    /// three-way "even" percentage split is the most common case there is.
    static func percentageSplits(
        amountMinor: Int,
        percentsBp: [String: Int],
        paidBy: String
    ) throws -> [String: Int] {
        let uids = percentsBp.keys.sorted()
        guard !uids.isEmpty else { throw SplitError.noParticipants }

        var totalBp = 0
        for uid in uids {
            let bp = percentsBp[uid] ?? -1
            guard bp >= 0 else { throw SplitError.badBasisPoints(uid: uid) }
            totalBp += bp
        }
        guard totalBp == 10_000 else { throw SplitError.percentagesDontTotal(totalBp) }

        var splits = [String: Int]()
        var sum = 0
        for uid in uids {
            // Truncate toward zero so drift has a consistent sign whether the
            // amount is a charge or a refund.
            let share = (amountMinor * (percentsBp[uid] ?? 0)) / 10_000
            splits[uid] = share
            sum += share
        }

        let drift = amountMinor - sum
        if drift != 0, let absorber = absorber(in: splits, paidBy: paidBy) {
            splits[absorber, default: 0] += drift
        }

        return splits
    }

    // MARK: - Intent

    /// Recompute splits from stored intent after a money or payer change.
    ///
    /// Returns nil for `.exact` — there's no correct answer for who absorbs a
    /// changed amount, so the caller must not guess. Block the save and open the
    /// split editor instead.
    static func splitsFromIntent(
        splitType: SplitType,
        amountMinor: Int,
        paidBy: String,
        equalParticipants: [String]?,
        splitPercentsBp: [String: Int]?,
        existingSplits: [String: Int]
    ) throws -> [String: Int]? {
        switch splitType {
        case .equal:
            let participants = equalParticipants ?? Array(existingSplits.keys)
            return try equalSplits(
                amountMinor: amountMinor,
                participants: participants,
                paidBy: paidBy
            )

        case .percentage:
            return try percentageSplits(
                amountMinor: amountMinor,
                percentsBp: splitPercentsBp ?? [:],
                paidBy: paidBy
            )

        case .exact:
            return nil
        }
    }

    // MARK: - Validation

    /// The invariant the server enforces: shares account for the whole amount,
    /// exactly. Block the save client-side rather than let the server flag it.
    static func isValid(splits: [String: Int], amountMinor: Int) -> Bool {
        guard !splits.isEmpty else { return false }
        return splits.values.reduce(0, +) == amountMinor
    }

    /// Signed shortfall, for the "Remaining" footer. Positive means unassigned.
    static func remaining(splits: [String: Int], amountMinor: Int) -> Int {
        amountMinor - splits.values.reduce(0, +)
    }
}

import Foundation

extension CostCard {
    // MARK: - Split logic

    func availableAmount(excluding id: String?) -> Double? {
        guard let total = info.totalAmount else { return nil }
        guard let excludeId = id else { return total }
        let digits = CurrencyInfo.fractionDigits(for: info.currencyCode)
        let assignedToOthers = info.participantAmounts.filter { $0.key != excludeId }.values.reduce(0, +)
        let remaining = (total - assignedToOthers).rounded(toPlaces: digits)
        return remaining > 0 ? remaining : 0
    }

    func availablePercentage(excluding id: String?) -> Double {
        guard let excludeId = id else { return 100 }
        let assignedToOthers = info.participantPercentages.filter { $0.key != excludeId }.values.reduce(0, +)
        let remaining = 100 - assignedToOthers
        return remaining > 0 ? remaining : 0
    }

    func recomputeSplit() {
        guard info.isSplitEnabled else { return }
        switch info.splitType {
        case .evenly:
            applyEqualSplit()
        case .percentage:
            applyPercentageSplit()
        case .manually:
            break
        }
    }

    /// Equal split via integer minor-unit math. The remainder cent goes to
    /// the payer (SplitMath rule), matching serialization and the server.
    func applyEqualSplit() {
        let allIDs = participantIDs + info.guests.map(\.id)
        guard let total = info.totalAmount, total > 0, !allIDs.isEmpty else { return }

        let includedIDs = allIDs.filter { !info.excludedFromEqualSplit.contains($0) }
        guard !includedIDs.isEmpty else {
            info.participantAmounts = [:]
            return
        }

        let code = info.currencyCode
        let digits = CurrencyInfo.fractionDigits(for: code)
        let totalMinor = CurrencyInfo.minorUnits(total, code: code)

        let shares = SplitMath.equalShares(
            totalMinor: totalMinor,
            includedIDs: includedIDs,
            payerId: info.paidByParticipantId
        )

        info.participantAmounts = shares.mapValues {
            SplitMath.toDisplay($0, fractionDigits: digits)
        }
    }

    /// Percentage split via integer basis points. No float epsilon checks;
    /// "assigned exactly 100%" is the exact integer test totalBp == 10000.
    func applyPercentageSplit() {
        let allIDs = participantIDs + info.guests.map(\.id)
        guard let total = info.totalAmount, total > 0, !allIDs.isEmpty else { return }

        let code = info.currencyCode
        let digits = CurrencyInfo.fractionDigits(for: code)
        let totalMinor = CurrencyInfo.minorUnits(total, code: code)

        let shares = SplitMath.percentageShares(
            totalMinor: totalMinor,
            percentages: info.participantPercentages,
            orderedIDs: allIDs,
            payerId: info.paidByParticipantId
        )

        info.participantAmounts = shares.mapValues {
            SplitMath.toDisplay($0, fractionDigits: digits)
        }
    }

    struct SplitStatus {
        let label: String
        let value: String
        let subLabel: String?
        let isBalanced: Bool
    }

    var splitStatus: SplitStatus? {
        guard let total = info.totalAmount, total > 0 else { return nil }

        // Compare in integer minor units — exact, no float equality risk.
        let code = info.currencyCode
        let digits = CurrencyInfo.fractionDigits(for: code)
        let totalMinor = CurrencyInfo.minorUnits(total, code: code)
        let assignedMinor = info.participantAmounts.values
            .map { CurrencyInfo.minorUnits($0, code: code) }
            .reduce(0, +)
        let remainingMinor = totalMinor - assignedMinor

        if remainingMinor == 0 {
            return SplitStatus(
                label: "Fully assigned",
                value: formatAmount(SplitMath.toDisplay(assignedMinor, fractionDigits: digits)),
                subLabel: nil,
                isBalanced: true
            )
        } else if remainingMinor > 0 {
            var subLabel: String? = nil
            if let payerId = info.paidByParticipantId {
                let name =
                    participants.first(where: { $0.id == payerId })?.displayName
                    ?? info.guests.first(where: { $0.id == payerId })?.name
                    ?? "Payer"
                subLabel = "Will be applied to \(name) when saved"
            }
            return SplitStatus(
                label: "Remaining",
                value: formatAmount(SplitMath.toDisplay(remainingMinor, fractionDigits: digits)),
                subLabel: subLabel,
                isBalanced: false
            )
        } else {
            return SplitStatus(
                label: "Over by",
                value: formatAmount(SplitMath.toDisplay(-remainingMinor, fractionDigits: digits)),
                subLabel: nil,
                isBalanced: false
            )
        }
    }
}

// MARK: - Helpers

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

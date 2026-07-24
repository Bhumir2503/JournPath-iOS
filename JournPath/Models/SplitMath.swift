import Foundation

enum SplitMath {
    static func remainderRecipient(includedIDs: [String], payerId: String?) -> String? {
        guard !includedIDs.isEmpty else { return nil }
        if let payerId, includedIDs.contains(payerId) { return payerId }
        return includedIDs.sorted()[0]
    }

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
            let share = totalMinor * bp / 10_000
            shares[id] = share
            assigned += share
        }

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

    static func toDisplay(_ minor: Int, fractionDigits: Int) -> Double {
        Double(minor) / pow(10.0, Double(fractionDigits))
    }
}

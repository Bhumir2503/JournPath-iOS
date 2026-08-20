import Foundation

/// Integer minor units only. No `Double` ever holds an amount.
///
/// A `Double` can represent 0.1 only approximately, so summing three shares of
/// a bill and comparing against the total fails unpredictably. Every amount in
/// the app is an `Int` of minor units plus the currency's exponent.
enum Money {

    // MARK: - Exponents

    /// Currencies whose minor unit is the major unit — ¥24,000 is 24000, not 2400000.
    private static let zeroDecimal: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG",
        "RWF", "UGX", "VND", "VUV", "XAF", "XOF", "XPF",
    ]

    /// Currencies with three decimal places.
    private static let threeDecimal: Set<String> = [
        "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND",
    ]

    /// Four decimal places. Rare, but CLF is a real unit of account.
    private static let fourDecimal: Set<String> = ["CLF"]

    /// The exponent that travels with the amount.
    ///
    /// Deliberately a hardcoded table rather than `NumberFormatter`, which is
    /// locale-dependent and can disagree with itself across devices. This value
    /// is persisted to Firestore and must be stable everywhere, forever.
    static func exponent(for currency: String) -> Int {
        let code = currency.uppercased()
        if zeroDecimal.contains(code) { return 0 }
        if threeDecimal.contains(code) { return 3 }
        if fourDecimal.contains(code) { return 4 }
        return 2
    }

    // MARK: - Parsing

    /// Parse raw keypad text ("162.5") into minor units for the given currency.
    ///
    /// String-based on purpose: routing through `Double` reintroduces the exact
    /// representation error the integer model exists to avoid.
    /// Returns nil if the text isn't a well-formed amount.
    static func minorUnits(from text: String, currency: String) -> Int? {
        let exp = exponent(for: currency)
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }

        let isNegative = trimmed.hasPrefix("-")
        let body = isNegative ? String(trimmed.dropFirst()) : trimmed

        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }

        let wholeText = parts[0].isEmpty ? "0" : String(parts[0])
        guard wholeText.allSatisfy(\.isNumber), let whole = Int(wholeText) else { return nil }

        var fraction = 0
        if parts.count == 2 {
            var fracText = String(parts[1])
            guard fracText.allSatisfy(\.isNumber) else { return nil }
            guard fracText.count <= exp else { return nil } // more precision than the currency has
            // "5" in a 2-decimal currency means 50 minor units, not 5.
            fracText += String(repeating: "0", count: exp - fracText.count)
            fraction = fracText.isEmpty ? 0 : (Int(fracText) ?? 0)
        }

        let scale = pow10(exp)
        let (scaled, overflow) = whole.multipliedReportingOverflow(by: scale)
        guard !overflow else { return nil }

        let magnitude = scaled + fraction
        return isNegative ? -magnitude : magnitude
    }

    // MARK: - Formatting

    /// Minor units as a plain decimal string ("16250" -> "162.50"). No symbol.
    static func decimalString(_ minor: Int, currency: String) -> String {
        let exp = exponent(for: currency)
        guard exp > 0 else { return String(minor) }

        let scale = pow10(exp)
        let isNegative = minor < 0
        let magnitude = abs(minor)

        let whole = magnitude / scale
        let fraction = magnitude % scale
        let fracText = String(format: "%0\(exp)d", fraction)

        return "\(isNegative ? "-" : "")\(whole).\(fracText)"
    }

    /// Localised currency string for display ("$162.50", "¥24,000").
    static func formatted(_ minor: Int, currency: String) -> String {
        let exp = exponent(for: currency)
        let value = Decimal(minor) / Decimal(pow10(exp))
        return value.formatted(.currency(code: currency).precision(.fractionLength(exp)))
    }

    /// Grouped display for the amount hero, preserving a fraction the user is
    /// still typing ("1234." stays "1,234." rather than snapping to "1,234").
    static func groupedDisplay(rawText: String, currency: String) -> String {
        guard !rawText.isEmpty else { return "0" }

        let parts = rawText.split(separator: ".", omittingEmptySubsequences: false)
        let whole = Int(parts[0]) ?? 0
        let grouped = whole.formatted(.number.grouping(.automatic))

        return parts.count > 1 ? "\(grouped).\(parts[1])" : grouped
    }

    /// The symbol shown next to the hero amount.
    static func symbol(for currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.currencySymbol ?? currency
    }

    // MARK: - Helpers

    private static func pow10(_ n: Int) -> Int {
        var result = 1
        for _ in 0..<n { result *= 10 }
        return result
    }
}

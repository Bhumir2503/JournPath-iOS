import Foundation

/// NumberFormatter creation is expensive; cache one per currency code.
enum CurrencyFormatterCache {
    private static var cache: [String: NumberFormatter] = [:]

    static func formatter(for code: String) -> NumberFormatter {
        if let cached = cache[code] { return cached }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = CurrencyInfo.locale(for: code)
        // The currency's real precision (JPY = 0, BHD = 3), not a hardcoded 2.
        let digits = CurrencyInfo.fractionDigits(for: code)
        formatter.maximumFractionDigits = digits
        formatter.minimumFractionDigits = digits
        cache[code] = formatter
        return formatter
    }
}

import Foundation

let codes = ["USD", "EUR", "GBP", "JPY", "INR", "VND", "IDR"]

for code in codes {
    // Try to find an "en_" locale first, or the shortest identifier
    let matchingLocales = Locale.availableIdentifiers.filter {
        let locale = Locale(identifier: $0)
        let localeCode: String?
        if #available(macOS 13.0, iOS 16.0, *) {
            localeCode = locale.currency?.identifier
        } else {
            localeCode = locale.currencyCode
        }
        return localeCode == code
    }
    
    // Sort to prefer "en_" or primary locales
    let bestId = matchingLocales.sorted { a, b in
        if a.hasPrefix("en_") && !b.hasPrefix("en_") { return true }
        if b.hasPrefix("en_") && !a.hasPrefix("en_") { return false }
        return a.count < b.count
    }.first ?? Locale.current.identifier
    
    let bestLocale = Locale(identifier: bestId)
    
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    formatter.locale = bestLocale
    
    print("\(code): \(formatter.string(from: 1000000.5) ?? "") (Locale: \(bestLocale.identifier))")
}

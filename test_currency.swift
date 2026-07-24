import Foundation

let codes = ["USD", "EUR", "GBP", "JPY", "INR", "VND", "IDR"]

for code in codes {
    var bestLocale: Locale = .current
    var shortestSymbol = code
    
    for identifier in Locale.availableIdentifiers {
        let locale = Locale(identifier: identifier)
        var localeCode: String?
        if #available(macOS 13.0, iOS 16.0, *) {
            localeCode = locale.currency?.identifier
        } else {
            localeCode = locale.currencyCode
        }
        
        if localeCode == code, let symbol = locale.currencySymbol {
            if symbol.count < shortestSymbol.count || bestLocale == .current {
                shortestSymbol = symbol
                bestLocale = locale
            }
        }
    }
    
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    formatter.locale = bestLocale
    
    print("\(code): \(formatter.string(from: 1000000.5) ?? "") (Locale: \(bestLocale.identifier))")
}

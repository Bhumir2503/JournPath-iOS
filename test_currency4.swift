import Foundation

let preferredLocales: [String: String] = [
    "USD": "en_US", "EUR": "en_IE", "GBP": "en_GB", "JPY": "en_JP",
    "INR": "en_IN", "AUD": "en_AU", "CAD": "en_CA", "CHF": "en_CH",
    "CNY": "en_CN", "NZD": "en_NZ", "MXN": "es_MX", "SGD": "en_SG",
    "HKD": "en_HK", "NOK": "en_NO", "KRW": "en_KR", "TRY": "en_TR",
    "RUB": "en_RU", "BRL": "pt_BR", "ZAR": "en_ZA", "SEK": "en_SE",
    "THB": "th_TH", "IDR": "en_ID", "VND": "vi_VN", "PHP": "en_PH",
    "AED": "en_AE", "EGP": "en_EG", "ILS": "en_IL", "SAR": "en_SA"
]

let codes = ["USD", "EUR", "GBP", "JPY", "INR", "VND", "IDR", "BRL", "CHF", "NOK"]

for code in codes {
    let bestLocale = Locale(identifier: preferredLocales[code] ?? "en_US")
    
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    formatter.locale = bestLocale
    
    print("\(code): \(formatter.string(from: 1000000.5) ?? "") (Locale: \(bestLocale.identifier))")
}

import Foundation

let explicitLocales: [String: String] = [
    "USD": "en_US", "EUR": "fr_FR", "GBP": "en_GB", "JPY": "ja_JP",
    "INR": "en_IN", "AUD": "en_AU", "CAD": "en_CA", "CHF": "de_CH",
    "CNY": "zh_CN", "NZD": "en_NZ", "MXN": "es_MX", "SGD": "en_SG",
    "HKD": "zh_HK", "NOK": "nb_NO", "KRW": "ko_KR", "TRY": "tr_TR",
    "RUB": "ru_RU", "BRL": "pt_BR", "ZAR": "en_ZA", "SEK": "sv_SE",
    "THB": "th_TH", "IDR": "id_ID", "VND": "vi_VN", "PHP": "en_PH"
]

let codes = ["USD", "EUR", "GBP", "JPY", "INR", "VND", "IDR"]

for code in codes {
    let localeIdentifier = explicitLocales[code] ?? Locale.current.identifier
    let bestLocale = Locale(identifier: localeIdentifier)
    
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    formatter.locale = bestLocale
    
    print("\(code): \(formatter.string(from: 1000000.5) ?? "") (Locale: \(bestLocale.identifier))")
}

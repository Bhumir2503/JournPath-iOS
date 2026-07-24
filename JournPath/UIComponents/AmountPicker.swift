import SwiftUI

struct AmountPicker: View {
    @Binding var amount: Double?
    @Binding var currencyCode: String
    var limit: Double? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var amountString: String = ""
    @State private var shakeAttempts: Int = 0

    private static let top5Currencies = ["USD", "EUR", "GBP", "JPY", "INR"]

    private static let next25Currencies = [
        "AUD", "CAD", "CHF", "CNY", "NZD",
        "MXN", "SGD", "HKD", "NOK", "KRW",
        "TRY", "RUB", "BRL", "ZAR", "SEK",
        "THB", "IDR", "VND", "PHP", "AED",
        "EGP", "ILS", "SAR", "MYR", "COP"
    ]

    private var effectiveMax: Double {
        let currencyMax = CurrencyInfo.maxAmount(for: currencyCode)
        guard let limit else { return currencyMax }
        return min(limit, currencyMax)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Amount display
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(CurrencyInfo.symbol(for: currencyCode))
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .foregroundStyle(amountString.isEmpty ? Color(UIColor.tertiaryLabel) : .primary)
                        Text(formattedAmount)
                            .font(.system(size: 64, weight: .semibold, design: .rounded))
                            .foregroundStyle(amountString.isEmpty ? Color(UIColor.tertiaryLabel) : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    if let limit {
                        Text("Max: \(formatLimit(limit))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .modifier(Shake(animatableData: CGFloat(shakeAttempts)))
                .animation(.default, value: shakeAttempts)

                Spacer()

                // Keypad
                CustomNumberPad(
                    text: $amountString,
                    maxFractionDigits: CurrencyInfo.fractionDigits(for: currencyCode),
                    maxAmount: effectiveMax
                ) {
                    withAnimation(.default) {
                        shakeAttempts += 1
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    currencyMenu
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        confirmAndDismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if let amount, amount > 0 {
                amountString = CurrencyInfo.editingString(for: amount, currencyCode: currencyCode)
            }
        }
        .onChange(of: currencyCode) { _, newCode in
            sanitizeAmount(for: newCode)
        }
    }

    // MARK: - Currency menu

    private var currencyMenu: some View {
        Menu {
            // Pickers render a native checkmark next to the current selection.
            Picker("Currency", selection: $currencyCode) {
                ForEach(Self.top5Currencies, id: \.self) { code in
                    Text(CurrencyInfo.menuLabel(for: code)).tag(code)
                }
            }
            .pickerStyle(.inline)

            Menu("More…") {
                Picker("More Currencies", selection: $currencyCode) {
                    ForEach(Self.next25Currencies, id: \.self) { code in
                        Text(CurrencyInfo.menuLabel(for: code)).tag(code)
                    }
                }
                .pickerStyle(.inline)
            }
        } label: {
            HStack(spacing: 6) {
                Text(currencyCode)
                Image(systemName: "chevron.up.chevron.down")
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemFill))
            .clipShape(Capsule())
        }
    }

    // MARK: - Actions

    private func confirmAndDismiss() {
        // Trim a trailing decimal separator so "12." still parses.
        var cleaned = amountString
        if cleaned.hasSuffix(".") {
            cleaned.removeLast()
        }

        // Zero and empty both mean "no amount" — never store 0.0, which
        // would render as a formatted zero while failing `total > 0` guards.
        if let val = Double(cleaned), val > 0 {
            amount = val
        } else {
            amount = nil
        }
        dismiss()
    }

    /// Re-validates the typed amount when the currency changes: truncates
    /// decimals the new currency doesn't support and clamps to its max.
    /// Never wipes the user's entry — clamping preserves intent.
    private func sanitizeAmount(for code: String) {
        guard !amountString.isEmpty else { return }

        let digits = CurrencyInfo.fractionDigits(for: code)
        var changed = false

        if let dotIndex = amountString.firstIndex(of: ".") {
            if digits == 0 {
                amountString = String(amountString[..<dotIndex])
                changed = true
            } else {
                let fractionStart = amountString.index(after: dotIndex)
                let fraction = amountString[fractionStart...]
                if fraction.count > digits {
                    let keepEnd = amountString.index(fractionStart, offsetBy: digits)
                    amountString = String(amountString[..<keepEnd])
                    changed = true
                }
            }
        }

        let maximum = limit.map { min($0, CurrencyInfo.maxAmount(for: code)) }
            ?? CurrencyInfo.maxAmount(for: code)
        if let val = Double(amountString), val > maximum {
            amountString = CurrencyInfo.editingString(for: maximum, currencyCode: code)
            changed = true
        }

        // One shake for any silent value change so it never goes unnoticed.
        if changed {
            withAnimation(.default) { shakeAttempts += 1 }
        }
    }

    // MARK: - Formatting

    private func formatLimit(_ limit: Double) -> String {
        CurrencyFormatterCache.formatter(for: currencyCode)
            .string(from: NSNumber(value: limit)) ?? ""
    }

    private var formattedAmount: String {
        let value = amountString.isEmpty ? "0" : amountString
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard let intPart = parts.first, let intValue = Int64(intPart) else { return value }

        let locale = CurrencyInfo.locale(for: currencyCode)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.maximumFractionDigits = 0

        let formattedInt = formatter.string(from: NSNumber(value: intValue)) ?? String(intValue)

        if parts.count > 1 {
            let decimalSeparator = locale.decimalSeparator ?? "."
            return formattedInt + decimalSeparator + parts[1]
        }
        return formattedInt
    }
}

// MARK: - Currency info (cached lookups)

/// All currency metadata is computed once and cached. Iterating
/// `Locale.availableIdentifiers` (~1000 locales) happens exactly once,
/// lazily, on first access.
enum CurrencyInfo {

    // MARK: Fraction digits / minor units

    /// ISO 4217 exponent exceptions. Everything absent defaults to 2.
    /// This is an explicit table — not derived from NumberFormatter — so the
    /// value is deterministic across OS versions and thread-safe by
    /// construction. It feeds every minor-unit conversion in the app, so it
    /// must be provably right. Covered by CurrencyInfoTests.
    private static let exponentExceptions: [String: Int] = [
        // Zero-decimal currencies
        "BIF": 0, "CLP": 0, "DJF": 0, "GNF": 0, "ISK": 0, "JPY": 0,
        "KMF": 0, "KRW": 0, "PYG": 0, "RWF": 0, "UGX": 0, "UYI": 0,
        "VND": 0, "VUV": 0, "XAF": 0, "XOF": 0, "XPF": 0,
        // Three-decimal currencies
        "BHD": 3, "IQD": 3, "JOD": 3, "KWD": 3, "LYD": 3, "OMR": 3, "TND": 3,
    ]

    /// Correct decimal places per currency: JPY/KRW = 0, BHD/KWD = 3, most = 2.
    static func fractionDigits(for code: String) -> Int {
        exponentExceptions[code.uppercased()] ?? 2
    }

    /// Converts a user-entered Double into integer minor units, safely.
    /// `.rounded()` absorbs Double representation artifacts
    /// (200.20999999… becomes exactly 20021). This is the single conversion
    /// used by CostCard's SplitMath, expenseFields(), and splitStatus — one
    /// definition so all three layers agree bit-for-bit.
    static func minorUnits(_ amount: Double, code: String) -> Int {
        let factor = pow(10.0, Double(fractionDigits(for: code)))
        return Int((amount * factor).rounded())
    }

    // MARK: Locale / symbol table

    /// One pass over all locales, done lazily on first access.
    /// Maps currency code -> (best formatting locale, shortest symbol).
    private static let table: [String: (locale: Locale, symbol: String)] = {
        var result: [String: (locale: Locale, symbol: String)] = [:]

        // 1. Curated locales for the currencies users will actually pick,
        // guaranteeing standard formatting. en_IE formats EUR like USD but
        // with € (€1,000,000.00); en_IN handles Indian grouping (₹10,00,000);
        // ja_JP is the canonical JPY locale (¥, no decimals, correct grouping).
        let preferredLocales: [String: String] = [
            "USD": "en_US", "EUR": "en_IE", "GBP": "en_GB", "JPY": "ja_JP",
            "INR": "en_IN", "AUD": "en_AU", "CAD": "en_CA", "CHF": "en_CH",
            "CNY": "zh_CN", "NZD": "en_NZ", "MXN": "es_MX", "SGD": "en_SG",
            "HKD": "en_HK", "NOK": "nb_NO", "KRW": "ko_KR", "TRY": "tr_TR",
            "RUB": "ru_RU", "BRL": "pt_BR", "ZAR": "en_ZA", "SEK": "sv_SE",
            "THB": "th_TH", "IDR": "id_ID", "VND": "vi_VN", "PHP": "en_PH",
            "AED": "en_AE", "EGP": "ar_EG", "ILS": "he_IL", "SAR": "ar_SA",
            "MYR": "ms_MY", "COP": "es_CO", "ARS": "es_AR", "CLP": "es_CL"
        ]

        for (code, id) in preferredLocales {
            let locale = Locale(identifier: id)
            if let symbol = locale.currencySymbol {
                result[code] = (locale, symbol)
            }
        }

        // 2. Fill gaps for uncurated currencies (first locale found wins) and
        // borrow shorter symbols for curated ones while keeping their
        // formatting locale.
        for identifier in Locale.availableIdentifiers {
            let locale = Locale(identifier: identifier)

            let code: String?
            if #available(iOS 16, *) {
                code = locale.currency?.identifier
            } else {
                code = locale.currencyCode
            }

            guard let code, let symbol = locale.currencySymbol else { continue }

            if let existing = result[code] {
                if symbol.count < existing.symbol.count {
                    result[code] = (existing.locale, symbol)
                }
            } else {
                result[code] = (locale, symbol)
            }
        }
        return result
    }()

    static func locale(for code: String) -> Locale {
        table[code]?.locale ?? .current
    }

    static func symbol(for code: String) -> String {
        if let symbol = table[code]?.symbol { return symbol }

        // Fallback: let NumberFormatter resolve it.
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }

    /// Per-currency entry cap. Zero-decimal currencies (JPY, KRW, VND…) are
    /// low-denomination, so a flat cap would be far too restrictive there —
    /// give them much more headroom (99 billion VND is ~$4M USD).
    static func maxAmount(for code: String) -> Double {
        fractionDigits(for: code) == 0 ? 99_999_999_999 : 99_999_999
    }

    static func menuLabel(for code: String) -> String {
        let name = Locale.current.localizedString(forCurrencyCode: code) ?? code
        return "\(symbol(for: code)) \(name)"
    }

    static func otherCurrencies(excluding top: [String]) -> [String] {
        Locale.commonISOCurrencyCodes
            .filter { !top.contains($0) }
            .sorted {
                let a = Locale.current.localizedString(forCurrencyCode: $0) ?? $0
                let b = Locale.current.localizedString(forCurrencyCode: $1) ?? $1
                return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
            }
    }

    /// String shown in the editor when reopening with an existing amount,
    /// respecting the currency's decimal places.
    static func editingString(for amount: Double, currencyCode: String) -> String {
        if amount == floor(amount) {
            return String(format: "%.0f", amount)
        }
        let digits = max(fractionDigits(for: currencyCode), 1)
        var s = String(format: "%.\(digits)f", amount)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}

// MARK: - Keypad

struct CustomNumberPad: View {
    @Binding var text: String
    var maxFractionDigits: Int
    var maxAmount: Double
    var onInvalidInput: () -> Void

    let rows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "<"],
    ]

    var body: some View {
        VStack(spacing: 24) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleKeyPress(key)
                        } label: {
                            Group {
                                if key == "<" {
                                    Image(systemName: "delete.backward")
                                } else {
                                    Text(key)
                                }
                            }
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .foregroundStyle(keyIsEnabled(key) ? .primary : Color(UIColor.tertiaryLabel))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(KeypadButtonStyle())
                    }
                }
            }
        }
    }

    /// Grey out the decimal key for zero-decimal currencies (JPY, KRW, …).
    private func keyIsEnabled(_ key: String) -> Bool {
        key == "." ? maxFractionDigits > 0 : true
    }

    private func reject() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        onInvalidInput()
    }

    private func handleKeyPress(_ key: String) {
        if key == "<" {
            guard !text.isEmpty else {
                reject()
                return
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            text.removeLast()
            return
        }

        if key == "." {
            guard maxFractionDigits > 0, !text.contains(".") else {
                reject()
                return
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // Typing "." on an empty field becomes "0."
            text = text.isEmpty ? "0." : text + "."
            return
        }

        // Digit key — enforce the currency's decimal places.
        if let dotIndex = text.firstIndex(of: ".") {
            let fractionCount = text.distance(from: text.index(after: dotIndex), to: text.endIndex)
            if fractionCount >= maxFractionDigits {
                reject()
                return
            }
        }

        let candidateText: String
        if text == "0" {
            candidateText = key  // replace a lone leading zero
        } else {
            candidateText = text + key
        }

        // Enforce the per-currency maximum.
        if let val = Double(candidateText), val > maxAmount {
            reject()
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        text = candidateText
    }
}

struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(UIColor.secondarySystemBackground) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct Shake: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX:
                    amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
                y: 0))
    }
}
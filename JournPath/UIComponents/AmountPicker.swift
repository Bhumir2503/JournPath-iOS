import SwiftUI

struct AmountPicker: View {
    @Binding var amount: Double?
    @Binding var currencyCode: String
    @Environment(\.dismiss) private var dismiss

    @State private var amountString: String = ""
    @State private var shakeAttempts: Int = 0

    private static let topCurrencies = ["USD", "EUR", "GBP", "JPY", "INR"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Amount Display
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
                .padding(.horizontal, 24)
                .modifier(Shake(animatableData: CGFloat(shakeAttempts)))
                .animation(.default, value: shakeAttempts)

                Spacer()

                // Keypad
                CustomNumberPad(
                    text: $amountString,
                    maxFractionDigits: CurrencyInfo.fractionDigits(for: currencyCode),
                    maxAmount: CurrencyInfo.maxAmount(for: currencyCode)
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

    // MARK: - Currency Menu

    private var currencyMenu: some View {
        Menu {
            // Pickers render a native checkmark next to the current selection.
            Picker("Currency", selection: $currencyCode) {
                ForEach(Self.topCurrencies, id: \.self) { code in
                    Text(CurrencyInfo.menuLabel(for: code)).tag(code)
                }
            }
            .pickerStyle(.inline)

            Menu("More…") {
                Picker("More Currencies", selection: $currencyCode) {
                    ForEach(CurrencyInfo.otherCurrencies(excluding: Self.topCurrencies), id: \.self) { code in
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

        if cleaned.isEmpty {
            amount = nil
        } else if let val = Double(cleaned) {
            amount = val
        }
        dismiss()
    }

    /// Re-validates the typed amount when the currency changes:
    /// truncates decimals the new currency doesn't support and clamps to its max.
    private func sanitizeAmount(for code: String) {
        guard !amountString.isEmpty else { return }

        let digits = CurrencyInfo.fractionDigits(for: code)

        if let dotIndex = amountString.firstIndex(of: ".") {
            if digits == 0 {
                amountString = String(amountString[..<dotIndex])
            } else {
                let fractionStart = amountString.index(after: dotIndex)
                let fraction = amountString[fractionStart...]
                if fraction.count > digits {
                    let keepEnd = amountString.index(fractionStart, offsetBy: digits)
                    amountString = String(amountString[..<keepEnd])
                }
            }
        }

        if let val = Double(amountString), val > CurrencyInfo.maxAmount(for: code) {
            amountString = ""
            withAnimation(.default) { shakeAttempts += 1 }
        }
    }

    // MARK: - Formatting

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

// MARK: - Currency Info (cached lookups)

/// All currency metadata is computed once and cached. The original code iterated
/// every `Locale.availableIdentifiers` (~1000 locales) on every access — and did
/// so for every row of the "More…" menu, which made opening it visibly slow.
enum CurrencyInfo {

    /// One pass over all locales, done lazily on first access.
    /// Maps currency code -> (best locale, shortest symbol).
    private static let table: [String: (locale: Locale, symbol: String)] = {
        var result: [String: (locale: Locale, symbol: String)] = [:]
        
        // 1. Curated list of safe locales to guarantee standard, flawless formatting.
        // For example, en_IE formats EUR exactly like USD but with € (e.g. €1,000,000.00).
        // en_IN flawlessly handles the Indian Rupee grouping (e.g. ₹10,00,000).
        let preferredLocales: [String: String] = [
            "USD": "en_US", "EUR": "en_IE", "GBP": "en_GB", "JPY": "en_JP",
            "INR": "en_IN", "AUD": "en_AU", "CAD": "en_CA", "CHF": "en_CH",
            "CNY": "en_CN", "NZD": "en_NZ", "MXN": "es_MX", "SGD": "en_SG",
            "HKD": "en_HK", "NOK": "en_NO", "KRW": "en_KR", "TRY": "en_TR",
            "RUB": "en_RU", "BRL": "pt_BR", "ZAR": "en_ZA", "SEK": "en_SE",
            "THB": "th_TH", "IDR": "en_ID", "VND": "vi_VN", "PHP": "en_PH",
            "AED": "en_AE", "EGP": "en_EG", "ILS": "en_IL", "SAR": "en_SA",
            "MYR": "en_MY", "COP": "es_CO", "ARS": "es_AR", "CLP": "es_CL"
        ]
        
        for (code, id) in preferredLocales {
            let locale = Locale(identifier: id)
            if let symbol = locale.currencySymbol {
                result[code] = (locale, symbol)
            }
        }
        
        // 2. Second pass: fill in gaps, and borrow shorter symbols where available.
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
                // If we find a tighter/shorter symbol, keep our solid formatting locale 
                // but just steal the shorter symbol!
                if symbol.count < existing.symbol.count {
                    result[code] = (existing.locale, symbol)
                }
            } else {
                // For totally unknown currencies, try to prefer an English-based locale.
                if result[code] == nil || identifier.hasPrefix("en_") {
                    result[code] = (locale, symbol)
                }
            }
        }
        return result
    }()

    private static var fractionDigitsCache: [String: Int] = [:]

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

    /// Correct decimal places per currency: JPY/KRW = 0, BHD/KWD = 3, most = 2.
    static func fractionDigits(for code: String) -> Int {
        if let cached = fractionDigitsCache[code] { return cached }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        let digits = formatter.maximumFractionDigits
        fractionDigitsCache[code] = digits
        return digits
    }

    /// Per-currency entry cap. Zero-decimal currencies (JPY, KRW, VND…) are
    /// low-denomination, so a flat 1,000,000 cap would be far too restrictive
    /// there — give them much more headroom (e.g. 99 billion VND is ~$4M USD).
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
        // Trim trailing zeros but keep at least one decimal digit's worth of intent.
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

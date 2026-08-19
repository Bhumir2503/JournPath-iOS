import SwiftUI

public struct AmountInputView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var text: String
    @Binding var currency: String

    var isFixedCurrency: Bool = false
    var limit: Double? = nil
    var onDone: (() -> Void)? = nil

    @State private var invalidAttempts: Int = 0

    private let topCurrencies = ["USD", "EUR", "JPY", "GBP", "INR"]

    private var otherCurrencies: [String] {
        SupportedCurrencies.all.filter { !topCurrencies.contains($0) }
    }

    // MARK: - Currency helpers

    private func symbol(for code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }

    private func fractionDigits(for code: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.maximumFractionDigits
    }

    private func menuLabel(for code: String) -> String {
        let sym = symbol(for: code)
        return sym == code ? code : "\(sym)  \(code)"
    }

    private func fullMenuLabel(for code: String) -> String {
        let name = Locale.current.localizedString(forCurrencyCode: code)
        guard let name, !name.isEmpty, name != code else { return menuLabel(for: code) }
        return "\(menuLabel(for: code)) — \(name)"
    }

    private var currencySymbol: String { symbol(for: currency) }
    private var maxFractionDigits: Int { fractionDigits(for: currency) }

    // MARK: - Amount display

    private var formattedAmount: String {
        guard !text.isEmpty else { return "0" }

        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let whole = Int(parts[0]) ?? 0
        let grouped = whole.formatted(.number.grouping(.automatic))

        return parts.count > 1 ? "\(grouped).\(parts[1])" : grouped
    }

    private var isSaveDisabled: Bool {
        text.isEmpty || text == "0" || isOverLimit
    }

    private var isOverLimit: Bool {
        guard let limit = limit, let val = Double(text) else { return false }
        return val > limit
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Massive Amount Display
                HStack(alignment: .bottom, spacing: 2) {
                    Text(currencySymbol)
                        .font(.system(size: 40, weight: .regular))
                        .padding(.bottom, 16)

                    Text(formattedAmount)
                        .font(.system(size: 100, weight: .regular))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }
                .foregroundStyle(isOverLimit ? Color.red : .primary)
                .contentTransition(.numericText())
                .shake(trigger: invalidAttempts)
                .padding(.horizontal, 24)

                if let limit = limit {
                    Text("Limit: \(limit.formatted(.currency(code: currency)))")
                        .font(.caption)
                        .foregroundColor(isOverLimit ? .red : .secondary)
                        .padding(.top, 8)
                }

                Spacer()

                // Bottom Area (Numpad)
                VStack(spacing: 0) {
                    Button {
                        if let onDone = onDone {
                            onDone()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text("Done")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(isSaveDisabled ? Color.primary.opacity(0.3) : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isSaveDisabled ? Color.gray.opacity(0.2) : Color.brand)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                    .disabled(isSaveDisabled)

                    NumberPad(
                        text: $text,
                        maxFractionDigits: maxFractionDigits,
                        limit: limit,
                        onError: { invalidAttempts += 1 }
                    )
                    .padding(.bottom, 32)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSaveDisabled)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isFixedCurrency {
                        Menu {
                            Picker("Currency", selection: $currency) {
                                ForEach(topCurrencies, id: \.self) { code in
                                    Text(menuLabel(for: code)).tag(code)
                                }
                            }
                            .pickerStyle(.inline)

                            Menu("More") {
                                Picker("Currency", selection: $currency) {
                                    ForEach(otherCurrencies, id: \.self) { code in
                                        Text(fullMenuLabel(for: code)).tag(code)
                                    }
                                }
                                .pickerStyle(.inline)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(currency)
                                    .font(.system(size: 15, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Number Pad

struct NumberPad: View {
    @Binding var text: String
    var maxFractionDigits: Int
    var limit: Double? = nil
    var onError: () -> Void

    private let rows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "delete.left"],
    ]

    private let defaultMaxLimit = 9_999_999_999.0  // 10 billion limit

    var body: some View {
        VStack(spacing: 32) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleKeyPress(key)
                        } label: {
                            keyLabel(key)
                        }
                        .accessibilityLabel(accessibilityLabel(for: key))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyLabel(_ key: String) -> some View {
        switch key {
        case "delete.left":
            Image(systemName: key)
                .font(.system(size: 26, weight: .light))
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.brand)
        case ".":
            Text(key)
                .font(.system(size: 34, weight: .regular))
                .frame(maxWidth: .infinity)
                .foregroundStyle(maxFractionDigits > 0 ? Color.brand : .clear)
        default:
            Text(key)
                .font(.system(size: 34, weight: .regular))
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.brand)
        }
    }

    private func accessibilityLabel(for key: String) -> String {
        switch key {
        case "delete.left": return "Delete"
        case ".": return "Decimal point"
        default: return key
        }
    }

    private func handleKeyPress(_ key: String) {
        switch key {
        case "delete.left":
            guard !text.isEmpty else { return onError() }
            text.removeLast()
            tap()

        case ".":
            guard maxFractionDigits > 0, !text.contains(".") else { return onError() }
            text = text.isEmpty ? "0." : text + "."
            tap()

        default:
            let newText = text == "0" ? key : text + key

            let parts = newText.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count > 1, parts[1].count > maxFractionDigits {
                return onError()
            }

            let limitValue = limit ?? defaultMaxLimit
            guard let value = Double(newText), value <= limitValue, newText.count < 15 else {
                return onError()
            }
            text = newText
            tap()
        }
    }

    private func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

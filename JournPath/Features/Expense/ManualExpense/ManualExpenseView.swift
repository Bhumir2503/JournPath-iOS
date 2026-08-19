import PhotosUI
import SwiftUI

struct ManualExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ParticipantStore.self) private var participantStore
    @Namespace private var animation

    @State private var amountText = ""
    @State private var invalidAttempts: Int = 0
    @State private var selectedCurrency = "USD"

    @State private var isReviewing = false
    @State private var expenseTitle = ""
    @State private var receiptItem: PhotosPickerItem?
    @State private var receiptImage: Image?
    @State private var category = "Shopping"
    @State private var splitType: SplitType = .evenly
    @State private var paidById: String? = nil

    @State private var evenlySplitParticipants: Set<String> = []
    @State private var manualSplits: [String: String] = [:]
    @State private var percentageSplits: [String: String] = [:]
    @State private var editingManualSplitFor: String?
    @State private var editingPercentageSplitFor: String?

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

    private var currencySymbol: String { symbol(for: selectedCurrency) }
    private var maxFractionDigits: Int { fractionDigits(for: selectedCurrency) }

    // MARK: - Amount display

    private var formattedAmount: String {
        guard !amountText.isEmpty else { return "0" }

        let parts = amountText.split(separator: ".", omittingEmptySubsequences: false)
        let whole = Int(parts[0]) ?? 0
        let grouped = whole.formatted(.number.grouping(.automatic))

        // Keep the trailing "." and any partial fraction the user is mid-typing.
        return parts.count > 1 ? "\(grouped).\(parts[1])" : grouped
    }

    private var isSaveDisabled: Bool {
        amountText.isEmpty || amountText == "0"
    }

    private var isSubmitDisabled: Bool {
        if expenseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        switch splitType {
        case .evenly:
            return evenlySplitParticipants.isEmpty
        case .manually:
            let total = Double(amountText) ?? 0
            let splitsSum = manualSplits.values.compactMap { Double($0) }.reduce(0, +)
            return abs(total - splitsSum) > 0.01
        case .percentage:
            let splitsSum = percentageSplits.values.compactMap { Double($0) }.reduce(0, +)
            return abs(100.0 - splitsSum) > 0.01
        }
    }

    @ViewBuilder
    private var remainingFooter: some View {
        switch splitType {
        case .evenly:
            EmptyView()
        case .manually:
            let total = Double(amountText) ?? 0
            let sum = manualSplits.values.compactMap { Double($0) }.reduce(0, +)
            let remaining = total - sum
            if abs(remaining) < 0.01 {
                Text("Fully split!")
                    .foregroundStyle(.green)
            } else {
                Text("Remaining: \(abs(remaining).formatted(.currency(code: selectedCurrency)))")
                    .foregroundStyle(remaining < 0 ? .red : .secondary)
            }
        case .percentage:
            let sum = percentageSplits.values.compactMap { Double($0) }.reduce(0, +)
            let remaining = 100.0 - sum
            if abs(remaining) < 0.01 {
                Text("Fully split!")
                    .foregroundStyle(.green)
            } else {
                Text("Remaining: \(abs(remaining).formatted())%")
                    .foregroundStyle(remaining < 0 ? .red : .secondary)
            }
        }
    }

    private var amountPerPerson: Double {
        let total = Double(amountText) ?? 0
        let count = evenlySplitParticipants.count
        return count > 0 ? total / Double(count) : 0
    }

    private func manualSplitLimit(for participantId: String) -> Double {
        let total = Double(amountText) ?? 0
        let otherSplitsSum = manualSplits.filter { $0.key != participantId }.compactMap { Double($0.value) }.reduce(0, +)
        return max(0, total - otherSplitsSum)
    }

    private func percentageSplitLimit(for participantId: String) -> Double {
        let total = 100.0
        let otherSplitsSum = percentageSplits.filter { $0.key != participantId }.compactMap { Double($0.value) }.reduce(0, +)
        return max(0, total - otherSplitsSum)
    }

    private var storageKey: String { "currency_\(participantStore.tripId)" }

    private let categories: [(name: String, icon: String, color: Color)] = [
        ("Food & Drink", "fork.knife", .orange),
        ("Travel", "airplane", .blue),
        ("Lodging", "bed.double.fill", .mint),
        ("Arts & Culture", "building.columns.fill", .purple),
        ("Entertainment", "sparkles", .pink),
        ("Recreation", "tree.fill", .green),
        ("Sports", "sportscourt.fill", .indigo),
        ("Water Sports", "figure.pool.swim", .cyan),
        ("Education", "books.vertical.fill", .brown),
        ("Health", "cross.case.fill", .red),
        ("Shopping", "bag.fill", .teal),
        ("Other", "ellipsis", .gray),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !isReviewing {
                    Spacer()

                    // Massive Amount Display
                    ExpenseAmountHeader(
                        currencySymbol: currencySymbol,
                        formattedAmount: formattedAmount,
                        invalidAttempts: invalidAttempts
                    )
                    .matchedGeometryEffect(id: "amount", in: animation)

                    Spacer()

                    // Bottom Area (Numpad)
                    VStack(spacing: 0) {
                        Button {
                            withAnimation {
                                isReviewing = true
                            }
                        } label: {
                            Text("Continue")
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
                            text: $amountText,
                            maxFractionDigits: maxFractionDigits,
                            onError: { invalidAttempts += 1 }
                        )
                        .padding(.bottom, 32)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    ExpenseAmountHeader(
                        currencySymbol: currencySymbol,
                        formattedAmount: formattedAmount,
                        invalidAttempts: invalidAttempts
                    )
                    .matchedGeometryEffect(id: "amount", in: animation)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .zIndex(1)

                    Form {
                        Section {
                            TextField("What was this for?", text: $expenseTitle)
                        }

                        Section {
                            Picker("Category", selection: $category) {
                                ForEach(categories, id: \.name) { cat in
                                    Label {
                                        Text(cat.name)
                                    } icon: {
                                        Image(systemName: cat.icon)
                                            .foregroundStyle(cat.color)
                                    }
                                    .tag(cat.name)
                                }
                            }
                            .pickerStyle(.navigationLink)
                        }

                        Section(header: Text("Details")) {
                            Picker(selection: $paidById) {
                                ForEach(participantStore.participants, id: \.id) { p in
                                    Text(p.displayName).tag(p.id as String?)
                                }
                            } label: {
                                Label("Paid By", systemImage: "creditcard")
                            }

                            Picker(selection: $splitType) {
                                ForEach(SplitType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            } label: {
                                Label("Split Type", systemImage: "arrow.triangle.branch")
                            }
                        }

                        Section(header: Text("Split With"), footer: remainingFooter) {
                            ExpenseSplitSection(
                                splitType: $splitType,
                                evenlySplitParticipants: $evenlySplitParticipants,
                                manualSplits: $manualSplits,
                                percentageSplits: $percentageSplits,
                                editingManualSplitFor: $editingManualSplitFor,
                                editingPercentageSplitFor: $editingPercentageSplitFor,
                                selectedCurrency: $selectedCurrency,
                                amountPerPerson: amountPerPerson,
                                currencySymbol: currencySymbol,
                                manualSplitLimit: manualSplitLimit,
                                percentageSplitLimit: percentageSplitLimit
                            )
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSaveDisabled)
            .animation(.default, value: isReviewing)
            .toolbar {
                if !isReviewing {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("Currency", selection: $selectedCurrency) {
                                ForEach(topCurrencies, id: \.self) { code in
                                    Text(menuLabel(for: code)).tag(code)
                                }
                            }
                            .pickerStyle(.inline)

                            Menu("More") {
                                Picker("Currency", selection: $selectedCurrency) {
                                    ForEach(otherCurrencies, id: \.self) { code in
                                        Text(fullMenuLabel(for: code)).tag(code)
                                    }
                                }
                                .pickerStyle(.inline)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedCurrency)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }.sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation { isReviewing = false }
                        } label: {
                            Text("Edit")
                                .font(.body.bold())
                        }
                    }.sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // save action
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(isSubmitDisabled)
                        .opacity(isSubmitDisabled ? 0.5 : 1.0)
                    }
                }
            }
        }
        .onAppear {
            if let saved = UserDefaults.standard.string(forKey: storageKey),
                SupportedCurrencies.isSupported(saved)
            {
                selectedCurrency = saved
            }
            if paidById == nil {
                paidById = participantStore.me?.id ?? participantStore.participants.first?.id
            }
            if evenlySplitParticipants.isEmpty {
                if let payerId = paidById {
                    evenlySplitParticipants = [payerId]
                }
            }
        }
        .onChange(of: selectedCurrency) { _, newValue in
            // Trim the fraction if the new currency doesn't take decimals (JPY, KRW…).
            if fractionDigits(for: newValue) == 0, amountText.contains(".") {
                amountText = String(amountText.split(separator: ".")[0])
            }
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }
}

// Note: NumberPad moved to UIComponents/AmountInputView.swift

#Preview {
    ManualExpenseView()
        .environment(ParticipantStore(tripId: "dummy"))
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

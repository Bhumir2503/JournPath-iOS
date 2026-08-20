import PhotosUI
import SwiftUI

struct ManualExpenseView: View {
    @Environment(TripStore.self) private var tripStore
    @Environment(SessionStore.self) private var sessionStore
    @Environment(ParticipantStore.self) private var participantStore

    var body: some View {
        ManualExpenseContentView(
            tripId: tripStore.tripId,
            currentUid: sessionStore.uid ?? "",
            participantIds: participantStore.participants.compactMap { $0.id }
        )
    }
}

struct ManualExpenseContentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ParticipantStore.self) private var participantStore
    @Namespace private var animation

    @State private var vm: ManualExpenseViewModel
    @State private var isReviewing = false
    @State private var receiptItem: PhotosPickerItem?

    private let topCurrencies = ["USD", "EUR", "JPY", "GBP", "INR"]

    private var otherCurrencies: [String] {
        SupportedCurrencies.all.filter { !topCurrencies.contains($0) }
    }

    init(tripId: String, currentUid: String, participantIds: [String], baseCurrency: String = "USD") {
        let saved = UserDefaults.standard.string(forKey: "currency_\(tripId)")
        let starting = (saved.flatMap { SupportedCurrencies.isSupported($0) ? $0 : nil }) ?? baseCurrency

        _vm = State(
            wrappedValue: ManualExpenseViewModel(
                tripId: tripId,
                currentUid: currentUid,
                participantIds: participantIds,
                defaultCurrency: starting
            )
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isReviewing {
                    reviewStage
                } else {
                    amountStage
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.amountIsEmpty)
            .animation(.default, value: isReviewing)
            .toolbar { toolbarContent }
        }
    }

    // MARK: - Stage one: amount

    private var amountStage: some View {
        Group {
            Spacer()

            ExpenseAmountHeader(
                currencySymbol: vm.currencySymbol,
                formattedAmount: vm.formattedAmount,
                invalidAttempts: vm.invalidAttempts
            )
            .matchedGeometryEffect(id: "amount", in: animation)

            Spacer()

            VStack(spacing: 0) {
                Button {
                    withAnimation { isReviewing = true }
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(vm.amountIsEmpty ? Color.primary.opacity(0.3) : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(vm.amountIsEmpty ? Color.gray.opacity(0.2) : Color.brand)
                        .clipShape(Capsule())
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
                .disabled(vm.amountIsEmpty)

                NumberPad(
                    text: $vm.amountText,
                    maxFractionDigits: vm.currencyExponent,
                    onError: { vm.invalidAttempts += 1 }
                )
                .padding(.bottom, 32)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Stage two: details

    private var reviewStage: some View {
        Group {
            ExpenseAmountHeader(
                currencySymbol: vm.currencySymbol,
                formattedAmount: vm.formattedAmount,
                invalidAttempts: vm.invalidAttempts
            )
            .matchedGeometryEffect(id: "amount", in: animation)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .zIndex(1)

            Form {
                Section {
                    TextField("What was this for?", text: $vm.title)
                }

                Section {
                    Picker("Category", selection: $vm.category) {
                        ForEach(ExpenseCategory.userSelectable) { category in
                            Label {
                                Text(category.displayName)
                            } icon: {
                                Image(systemName: category.icon)
                                    .foregroundStyle(category.color)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section(header: Text("Details")) {
                    Picker(selection: $vm.paidById) {
                        ForEach(participantStore.participants, id: \.id) { p in
                            Text(p.displayName).tag(p.id ?? "")
                        }
                    } label: {
                        Label("Paid By", systemImage: "creditcard")
                    }

                    Picker(selection: $vm.splitType) {
                        ForEach(SplitType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    } label: {
                        Label("Split Type", systemImage: "arrow.triangle.branch")
                    }

                    // Date of spending, not of logging. Drives which day's rate
                    // table the server converts against, so a receipt entered
                    // three days late still uses the rate from the day you paid.
                    DatePicker(
                        selection: $vm.spentAt,
                        in: ...Date(),
                        displayedComponents: .date
                    ) {
                        Label("Date", systemImage: "calendar")
                    }

                }

                Section(header: Text("Split With"), footer: remainingFooter) {
                    ExpenseSplitSection(vm: vm)
                }

                Section {
                    TextField("Notes", text: $vm.notes, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var remainingFooter: some View {
        if let error = vm.splitError {
            Text(error).foregroundStyle(.red)
        } else if vm.splitType == .equal {
            EmptyView()
        } else if vm.isFullySplit {
            Text("Fully split!").foregroundStyle(.green)
        } else if vm.splitType == .percentage {
            let remaining = Double(vm.remainingPercentBp) / 100
            Text("Remaining: \(abs(remaining).formatted())%")
                .foregroundStyle(remaining < 0 ? .red : .secondary)
        } else {
            Text("Remaining: \(vm.formatted(abs(vm.remaining)))")
                .foregroundStyle(vm.remaining < 0 ? .red : .secondary)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isReviewing {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation { isReviewing = false }
                } label: {
                    Text("Edit").font(.body.bold())
                }
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if vm.save() { dismiss() }
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.glassProminent)
                .disabled(!vm.canSubmit || vm.isSaving)
                .opacity(vm.canSubmit ? 1.0 : 0.5)
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Currency", selection: $vm.selectedCurrency) {
                        ForEach(topCurrencies, id: \.self) { code in
                            Text(menuLabel(for: code)).tag(code)
                        }
                    }
                    .pickerStyle(.inline)

                    Menu("More") {
                        Picker("Currency", selection: $vm.selectedCurrency) {
                            ForEach(otherCurrencies, id: \.self) { code in
                                Text(fullMenuLabel(for: code)).tag(code)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(vm.selectedCurrency)
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    // MARK: - Currency labels

    private func menuLabel(for code: String) -> String {
        let symbol = Money.symbol(for: code)
        return symbol == code ? code : "\(symbol)  \(code)"
    }

    private func fullMenuLabel(for code: String) -> String {
        guard let name = Locale.current.localizedString(forCurrencyCode: code),
            !name.isEmpty, name != code
        else { return menuLabel(for: code) }
        return "\(menuLabel(for: code)) — \(name)"
    }
}

#Preview {
    ManualExpenseContentView(
        tripId: "dummy",
        currentUid: "me",
        participantIds: ["me", "alice", "bob"]
    )
    .environment(ParticipantStore(tripId: "dummy"))
}

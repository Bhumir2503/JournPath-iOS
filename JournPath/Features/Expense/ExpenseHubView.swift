import FirebaseCore
import SwiftUI

struct ExpenseHubView: View {
    @Environment(TripStore.self) private var tripStore
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        ExpenseHubContentView(tripId: tripStore.tripId, currentUid: sessionStore.uid ?? "")
    }
}

struct ExpenseHubContentView: View {
    @Environment(ParticipantStore.self) private var participantStore

    @State private var expenseStore: ExpenseStore
    @State private var ledgerStore: LedgerStore

    @State private var showAdd = false
    @State private var selectedCategory: ExpenseCategory?
    @State private var selectedExpense: Expense?

    private let tripId: String
    private let currentUid: String

    init(tripId: String, currentUid: String) {
        self.tripId = tripId
        self.currentUid = currentUid
        _expenseStore = State(wrappedValue: ExpenseStore(tripId: tripId))
        _ledgerStore = State(wrappedValue: LedgerStore(tripId: tripId))
    }

    private var baseCurrency: String { ledgerStore.baseCurrency }

    private var filteredExpenses: [Expense] {
        guard let selectedCategory else { return expenseStore.expenses }
        return expenseStore.expenses.filter { $0.category == selectedCategory }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                Section {
                    balanceHero
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if !expenseStore.flagged.isEmpty {
                    Section {
                        reviewBanner
                    }
                }

                Section {
                    spendStats
                        .listRowInsets(EdgeInsets())
                }

                let myTransfers = ledgerStore.transfers(involving: currentUid)
                if !myTransfers.isEmpty {
                    Section(header: Text("Settle up")) {
                        ForEach(myTransfers) { transfer in
                            settleRow(for: transfer)
                        }
                    }
                }

                Section {
                    if expenseStore.isLoading {
                        HStack {
                            ProgressView()
                            Text("Loading…")
                                .foregroundStyle(.secondary)
                        }
                    } else if filteredExpenses.isEmpty {
                        if selectedCategory == nil {
                            ContentUnavailableView(
                                "No Expenses",
                                systemImage: "tray",
                                description: Text("Expenses you add will appear here.")
                            )
                            .padding(.top, 80)
                            .listRowBackground(Color.clear)
                        } else {
                            ContentUnavailableView(
                                "Nothing Found",
                                systemImage: "line.3.horizontal.decrease",
                                description: Text("There are no expenses in this category.")
                            )
                            .padding(.top, 80)
                            .listRowBackground(Color.clear)
                        }
                    } else {
                        ForEach(filteredExpenses) { expense in
                            Button {
                                selectedExpense = expense
                            } label: {
                                ExpenseRow(
                                    expense: expense,
                                    currentUid: currentUid,
                                    baseCurrency: baseCurrency,
                                    payerName: displayName(for: expense.paidBy)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    expenseHeader
                        .textCase(nil)
                        .padding(.bottom, 4)
                        .padding(.horizontal, -4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .scrollIndicators(.hidden)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus").fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                ManualExpenseView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedExpense) { expense in
                ExpensePreviewView(
                    expense: expense,
                    currentUid: currentUid,
                    baseCurrency: baseCurrency,
                    onDelete: {
                        if let id = expense.id {
                            ExpenseService().delete(id: id, in: tripId)
                        }
                    }
                )
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Balance hero

    private var balanceHero: some View {
        let balance = ledgerStore.balance(for: currentUid)

        return VStack(spacing: 6) {
            Text(signedAmount(balance))
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(balanceCaption(balance))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func balanceCaption(_ balance: Int) -> String {
        if balance > 0 { return "You are owed" }
        if balance < 0 { return "You owe" }
        return ledgerStore.ledger == nil ? "Nothing to settle yet" : "All settled up"
    }

    /// Sign is carried explicitly so a negative reads "-¥4,500" rather than
    /// whatever the locale does with parentheses or trailing minus.
    private func signedAmount(_ minor: Int) -> String {
        let formatted = Money.formatted(abs(minor), currency: baseCurrency)
        if minor > 0 { return "+\(formatted)" }
        if minor < 0 { return "-\(formatted)" }
        return formatted
    }

    // MARK: - Review banner

    private var reviewBanner: some View {
        let count = expenseStore.flagged.count

        return HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(count == 1 ? "1 expense needs review" : "\(count) expenses need review")
                    .font(.subheadline.weight(.medium))
                // These are excluded from every number above, so say so —
                // silently wrong balances are worse than visibly incomplete ones.
                Text("The amounts don't add up, so they're left out of balances.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Spend stats

    private var spendStats: some View {
        HStack(spacing: 0) {
            StatCell(
                label: "Trip total",
                value: Money.formatted(expenseStore.tripTotalBase, currency: baseCurrency),
                accent: false
            )
            Divider()
            StatCell(
                label: "You paid",
                value: Money.formatted(expenseStore.totalPaid(by: currentUid), currency: baseCurrency),
                accent: false
            )
            Divider()
            StatCell(
                label: "Your share",
                value: Money.formatted(expenseStore.totalShare(for: currentUid), currency: baseCurrency),
                accent: true
            )
        }
    }

    // MARK: - Settle row

    private func settleRow(for transfer: LedgerTransfer) -> some View {
        let owesMe = transfer.to == currentUid
        let otherUid = owesMe ? transfer.from : transfer.to

        return HStack(spacing: 14) {
            if let participant = participant(for: otherUid) {
                ParticipantAvatar(participant: participant, size: .small)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    owesMe
                        ? "\(displayName(for: otherUid)) owes you"
                        : "You owe \(displayName(for: otherUid))")
                Text("Tap to record payment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Money.formatted(transfer.amountMinor, currency: baseCurrency))
                .fontWeight(.semibold)
                .foregroundStyle(owesMe ? .green : .red)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Expense header

    private var expenseHeader: some View {
        HStack {
            Text("Expenses")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Menu {
                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag(ExpenseCategory?.none)
                    ForEach(ExpenseCategory.allCases) { category in
                        Label(category.displayName, systemImage: category.icon)
                            .tag(ExpenseCategory?.some(category))
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(selectedCategory != nil ? Color.accentColor : .secondary)
                }
            }
        }
    }

    // MARK: - Participants

    private func participant(for uid: String) -> Participant? {
        participantStore.participants.first { $0.id == uid }
    }

    private func displayName(for uid: String) -> String {
        if uid == currentUid { return "You" }
        return participant(for: uid)?.displayName ?? "Someone"
    }
}

// MARK: - Stat cell

private struct StatCell: View {
    let label: String
    let value: String
    let accent: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.3)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(accent ? Color.accentColor : .primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Expense row

private struct ExpenseRow: View {
    let expense: Expense
    let currentUid: String
    let baseCurrency: String
    let payerName: String

    private var isForeignCurrency: Bool {
        expense.currency != baseCurrency
    }

    var body: some View {
        HStack(spacing: 14) {
            categoryTile

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .lineLimit(1)

                Text("\(payerName) paid · \(relativeDate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                // Lead with what was actually paid, in the currency it was paid in.
                Text(Money.formatted(expense.amountMinor, currency: expense.currency))

                // The ≈ line only earns its place on a foreign-currency expense.
                if isForeignCurrency, let base = expense.baseAmountMinor {
                    Text("≈ \(Money.formatted(base, currency: baseCurrency))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if expense.effectiveRateStatus == .pending {
                    Text("Syncing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if expense.isFlagged {
                    Text("Review")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if let net = expense.netEffect(for: currentUid), net != 0 {
                    Text(signed(net))
                        .font(.caption)
                        .foregroundStyle(net > 0 ? .green : .red)
                }
            }
        }
    }

    private var categoryTile: some View {
        let category = expense.category ?? .other

        return Image(systemName: category.icon)
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(category.color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func signed(_ minor: Int) -> String {
        let formatted = Money.formatted(abs(minor), currency: baseCurrency)
        return minor > 0 ? "+\(formatted)" : "-\(formatted)"
    }

    private var relativeDate: String {
        let date = expense.spentAt.dateValue()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview {
    ExpenseHubContentView(tripId: "dummy", currentUid: "me")
        .environment(ParticipantStore(tripId: "dummy"))
}

import SwiftUI

// MARK: - Dummy Data

private struct DummyParticipant: Identifiable {
    let id: String
    let name: String
    let color: Color
    var initial: String { String(name.prefix(1)) }
}

private struct DummyExpense: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let categoryIcon: String
    let categoryColor: Color
    let paidBy: String
    let amount: Int
    let netEffect: Int
    let dateString: String
}

private struct DummyTransfer: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    let amount: Int
    let color: Color
}

private let participants: [DummyParticipant] = [
    .init(id: "You", name: "You", color: .blue),
    .init(id: "Alex", name: "Alex", color: .green),
    .init(id: "Jack", name: "Priya", color: .orange),
    .init(id: "Bhumir", name: "Bhumi", color: .purple),
]

private let dummyExpenses: [DummyExpense] = [
    .init(title: "Ramen dinner", category: "Food", categoryIcon: "fork.knife", categoryColor: .orange, paidBy: "Alex", amount: 6800, netEffect: -1700, dateString: "Today"),
    .init(title: "Shinkansen", category: "Transport", categoryIcon: "tram.fill", categoryColor: .blue, paidBy: "You", amount: 24000, netEffect: 18000, dateString: "Today"),
    .init(title: "Airbnb night 1", category: "Stay", categoryIcon: "bed.double.fill", categoryColor: .green, paidBy: "Jack", amount: 18000, netEffect: -4500, dateString: "Yesterday"),
    .init(title: "TeamLab tickets", category: "Activity", categoryIcon: "ticket.fill", categoryColor: .pink, paidBy: "You", amount: 12000, netEffect: 9000, dateString: "Yesterday"),
    .init(title: "7-Eleven run", category: "Food", categoryIcon: "fork.knife", categoryColor: .orange, paidBy: "Bhumir", amount: 2400, netEffect: -600, dateString: "Yesterday"),
]

private let transfers: [DummyTransfer] = [
    .init(from: "Alex", to: "You", amount: 9000, color: .green),
    .init(from: "Bhumir", to: "You", amount: 11200, color: .purple),
]

// MARK: - Root

struct ExpenseDummyView: View {

    @State private var showAdd = false
    @State private var selectedCategory = "All"

    var body: some View {
        NavigationStack {
            List {

                // Balance hero
                Section {
                    balanceHero
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                // Spend stats
                Section {
                    spendStats
                        .listRowInsets(EdgeInsets())
                }

                // Settle up
                Section(header: Text("Settle up")) {
                    ForEach(transfers) { t in
                        settleRow(for: t)
                    }
                }

                // Expenses
                Section {
                    let filtered =
                        selectedCategory == "All"
                        ? dummyExpenses
                        : dummyExpenses.filter { $0.category == selectedCategory }

                    ForEach(filtered) { e in
                        ExpenseRow(expense: e)
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
                AddExpenseSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }.presentationDragIndicator(.visible)
    }

    // MARK: Balance hero

    private var balanceHero: some View {
        VStack(spacing: 6) {
            Text("+¥20,200")
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text("You are owed")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: Spend stats

    private var spendStats: some View {
        HStack(spacing: 0) {
            StatCell(label: "Trip total", value: "¥63,200", accent: false)
            Divider()
            StatCell(label: "You paid", value: "¥36,000", accent: false)
            Divider()
            StatCell(label: "Your share", value: "¥15,800", accent: true)
        }
    }

    // MARK: Settle row

    private func settleRow(for t: DummyTransfer) -> some View {
        HStack(spacing: 14) {
            Bubble(initial: String(t.from.prefix(1)), color: t.color, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(t.from) owes you")
                Text("Tap to record payment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("¥\(t.amount.formatted())")
                .fontWeight(.semibold)
                .foregroundStyle(.green)
        }
        .padding(.vertical, 4)
    }

    // MARK: Expense header

    private var expenseHeader: some View {
        HStack {
            Text("Expenses")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            Menu {
                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag("All")
                    Text("Food").tag("Food")
                    Text("Transport").tag("Transport")
                    Text("Stay").tag("Stay")
                    Text("Activity").tag("Activity")
                    Text("Shopping").tag("Shopping")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                    if selectedCategory != "All" {
                        Text(selectedCategory)
                            .font(.system(size: 13))
                    }
                }
                .foregroundStyle(selectedCategory != "All" ? Color.accentColor : .secondary)
            }
        }
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Add expense sheet

private struct AddExpenseSheet: View {

    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var title = ""
    @State private var paidBy = participants[0].id
    @State private var category = "Food"
    @State private var splitType = "Equal"
    @State private var included: Set<String> = Set(participants.map(\.id))
    @State private var exactAmounts: [String: String] = [:]
    @State private var percentAmounts: [String: String] = [:]
    @State private var date = Date()

    private let splitTypes = ["Equal", "Exact", "%"]
    private let categoryOptions = ["Food", "Transport", "Stay", "Activity", "Shopping", "Other"]
    private var canSave: Bool { !amountText.isEmpty && !title.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    amountHero.padding(.vertical, 16)
                }
                .listRowBackground(Color.clear)

                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 17))
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                        TextField("Description", text: $title)
                    }

                    Picker(selection: $paidBy) {
                        ForEach(participants) { p in
                            Text(p.name).tag(p.id)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person")
                                .font(.system(size: 17))
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                            Text("Paid by")
                        }
                    }

                    Picker(selection: $category) {
                        ForEach(categoryOptions, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            categoryIcon(for: category).frame(width: 28)
                            Text("Category")
                        }
                    }

                    DatePicker(selection: $date, displayedComponents: .date) {
                        HStack(spacing: 14) {
                            Image(systemName: "calendar")
                                .font(.system(size: 17))
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                            Text("Date")
                        }
                    }
                }

                Section(header: Text("Split")) {
                    Picker("Split Type", selection: $splitType) {
                        ForEach(splitTypes, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)

                    ForEach(participants) { p in
                        HStack(spacing: 14) {
                            Bubble(initial: p.initial, color: p.color, size: 32)
                            Text(p.name).font(.system(size: 17))
                            Spacer()
                            splitControl(for: p)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("New expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { dismiss() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: Amount hero

    private var amountHero: some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("¥")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
                TextField("0", text: $amountText)
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .foregroundStyle(amountText.isEmpty ? .secondary : .primary)
                    .keyboardType(.numberPad)
                    .fixedSize(horizontal: true, vertical: false)
            }
            Button {
            } label: {
                HStack(spacing: 4) {
                    Text("JPY")
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 11))
                }
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Split control

    @ViewBuilder
    private func splitControl(for p: DummyParticipant) -> some View {
        switch splitType {
        case "Equal":
            Toggle(
                "",
                isOn: Binding(
                    get: { included.contains(p.id) },
                    set: { on in
                        if on { included.insert(p.id) } else if included.count > 1 { included.remove(p.id) }
                    }
                )
            )
            .labelsHidden()

        case "Exact":
            TextField(
                "¥0",
                text: Binding(
                    get: { exactAmounts[p.id] ?? "" },
                    set: { exactAmounts[p.id] = $0 }
                )
            )
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
            .keyboardType(.numberPad)

        default:
            HStack(spacing: 2) {
                TextField(
                    "0",
                    text: Binding(
                        get: { percentAmounts[p.id] ?? "" },
                        set: { percentAmounts[p.id] = $0 }
                    )
                )
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
                .keyboardType(.numberPad)
                Text("%").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Category icon

    private func categoryIcon(for name: String) -> some View {
        let map: [String: (String, Color)] = [
            "Food": ("fork.knife", .orange),
            "Transport": ("tram.fill", .blue),
            "Stay": ("bed.double.fill", .green),
            "Activity": ("ticket.fill", .pink),
            "Shopping": ("bag.fill", .purple),
            "Other": ("ellipsis.circle", .gray),
        ]
        let match = map[name] ?? ("ellipsis.circle", .gray)
        return Image(systemName: match.0)
            .font(.system(size: 17))
            .foregroundStyle(match.1)
    }
}

// MARK: - Shared subviews

private struct Bubble: View {
    let initial: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
    }
}

private struct ExpenseRow: View {
    let expense: DummyExpense

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: expense.categoryIcon)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(expense.categoryColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                Text("\(expense.paidBy) paid · \(expense.dateString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("¥\(expense.amount.formatted())")
                Text(
                    expense.netEffect >= 0
                        ? "+¥\(expense.netEffect.formatted())"
                        : "-¥\(abs(expense.netEffect).formatted())"
                )
                .font(.caption)
                .foregroundStyle(expense.netEffect >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ExpenseDummyView()
}

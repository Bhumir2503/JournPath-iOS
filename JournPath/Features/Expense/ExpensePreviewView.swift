import FirebaseCore
import SwiftUI

struct ExpensePreviewView: View {
    let expense: Expense
    let currentUid: String
    let baseCurrency: String

    @Environment(\.dismiss) private var dismiss
    @Environment(ParticipantStore.self) private var participantStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        categoryTile

                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.title)
                                .font(.headline)
                            if let notes = expense.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Details") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text(Money.formatted(expense.amountMinor, currency: expense.currency))
                    }

                    if expense.currency != baseCurrency, let baseAmount = expense.baseAmountMinor {
                        HStack {
                            Text("Base Amount")
                            Spacer()
                            Text(Money.formatted(baseAmount, currency: baseCurrency))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Paid By")
                        Spacer()
                        Text(displayName(for: expense.paidBy))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Date")
                        Spacer()
                        Text(expense.spentAt.dateValue().formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }

                let splits = expense.baseSplits ?? expense.splits
                Section("Splits") {
                    ForEach(Array(splits.keys.sorted()), id: \.self) { uid in
                        if let splitAmount = splits[uid] {
                            HStack {
                                Text(displayName(for: uid))
                                Spacer()
                                Text(Money.formatted(splitAmount, currency: expense.baseAmountMinor != nil ? baseCurrency : expense.currency))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Expense Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var categoryTile: some View {
        let category = expense.category ?? .other

        return Image(systemName: category.icon)
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(category.color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func displayName(for uid: String) -> String {
        if uid == currentUid { return "You" }
        return participantStore.participants.first { $0.id == uid }?.displayName ?? "Someone"
    }
}

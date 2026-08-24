import FirebaseCore
import SwiftUI

struct ExpensePreviewView: View {
    let expense: Expense
    let currentUid: String
    let baseCurrency: String
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(ParticipantStore.self) private var participantStore

    @State private var showDeleteConfirm = false

    private var isForeign: Bool { expense.currency != baseCurrency }
    private var category: ExpenseCategory { expense.category ?? .other }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    hero

                    if expense.isFlagged {
                        statusBanner(
                            icon: "exclamationmark.triangle.fill",
                            tint: .orange,
                            title: "Needs review",
                            message: "The shares don't add up to the total, so this is left out of everyone's balance."
                        )
                    } else if expense.effectiveRateStatus == .pending {
                        statusBanner(
                            icon: "clock.fill",
                            tint: .secondary,
                            title: "Waiting on an exchange rate",
                            message: "It'll be added to balances once the rate for this date arrives."
                        )
                    }

                    yourPosition
                    detailsCard
                    splitsCard

                    if let footnote = rateFootnote {
                        Text(footnote)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    if onDelete != nil {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Expense")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog(
                "Delete this expense?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                // Deleting money changes what everyone owes, so say so plainly.
                Text("Everyone's balance will be recalculated without it.")
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 60, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 120, height: 120)
                .background(category.color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .padding(.bottom, 2)

            Text(Money.formatted(expense.amountMinor, currency: expense.currency))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            VStack(spacing: 3) {
                Text(expense.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(expense.spentAt.dateValue().formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }

    // MARK: - Status

    private func statusBanner(icon: String, tint: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.subheadline)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Your position

    /// The two numbers the reader actually opened this sheet for: what they owe
    /// on this expense, and what it did to their balance.
    @ViewBuilder
    private var yourPosition: some View {
        let myShare = expense.baseSplits?[currentUid] ?? expense.splits[currentUid]
        let shareCurrency = expense.baseSplits != nil ? baseCurrency : expense.currency
        let net = expense.netEffect(for: currentUid)

        if myShare != nil || net != nil {
            HStack(spacing: 0) {
                statCell(
                    label: "Your share",
                    value: myShare.map { Money.formatted($0, currency: shareCurrency) } ?? "—",
                    tint: .primary
                )

                Divider().frame(height: 34)

                statCell(
                    label: net.map { $0 >= 0 ? "You're owed" : "You owe" } ?? "Net effect",
                    value: net.map { Money.formatted(abs($0), currency: baseCurrency) } ?? "—",
                    tint: net.map { $0 == 0 ? .primary : ($0 > 0 ? .green : .red) } ?? .secondary
                )
            }
            .padding(.vertical, 14)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)
        }
    }

    private func statCell(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.3)
            Text(value)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Details

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "Paid by") {
                HStack(spacing: 8) {
                    if let participant = participant(for: expense.paidBy) {
                        ParticipantAvatar(participant: participant, size: .small)
                    }
                    Text(displayName(for: expense.paidBy))
                        .foregroundStyle(.primary)
                }
            }

            rowDivider

            detailRow(label: "Category") {
                HStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .font(.caption)
                        .foregroundStyle(category.color)
                    Text(category.displayName)
                }
            }

            rowDivider

            detailRow(label: "Split") {
                Text(splitDescription)
            }

            if let notes = expense.notes, !notes.isEmpty {
                rowDivider

                VStack(alignment: .leading, spacing: 5) {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(notes)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private func detailRow<Content: View>(
        label: String,
        @ViewBuilder value: () -> Content
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            value()
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 16)
    }

    private var splitDescription: String {
        switch expense.splitType {
        case .equal:
            let count = expense.equalParticipants?.count ?? expense.splits.count
            return "Evenly · \(count) \(count == 1 ? "person" : "people")"
        case .exact:
            return "Exact amounts"
        case .percentage:
            return "By percentage"
        }
    }

    // MARK: - Splits

    private var splitsCard: some View {
        // Always lead with the currency actually paid — that's what people
        // agreed to. The base conversion is secondary, and only shown when the
        // two differ.
        let uids = expense.splits.keys.sorted { displayName(for: $0) < displayName(for: $1) }

        return VStack(alignment: .leading, spacing: 0) {
            Text("Split between")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.3)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ForEach(Array(uids.enumerated()), id: \.element) { index, uid in
                HStack(spacing: 12) {
                    if let participant = participant(for: uid) {
                        ParticipantAvatar(participant: participant, size: .small)
                    }

                    Text(displayName(for: uid))
                        .font(.subheadline)

                    if uid == expense.paidBy {
                        Text("paid")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Money.formatted(expense.splits[uid] ?? 0, currency: expense.currency))
                            .font(.subheadline.weight(.medium))

                        if isForeign, let base = expense.baseSplits?[uid] {
                            Text("≈ \(Money.formatted(base, currency: baseCurrency))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if index != uids.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .padding(.bottom, 6)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Rate footnote

    /// Shows the conversion actually applied. Worth surfacing: it's the one
    /// number people question when a foreign expense looks off, and naming the
    /// date makes the walk-back behaviour visible rather than mysterious.
    private var rateFootnote: String? {
        guard isForeign, let rate = expense.rateUsed else { return nil }

        let formatted = rate.formatted(.number.precision(.significantDigits(1...6)))
        guard let docId = expense.rateDocId else {
            return "Converted at 1 \(expense.currency) = \(formatted) \(baseCurrency)."
        }
        return "Converted at 1 \(expense.currency) = \(formatted) \(baseCurrency), using rates from \(docId)."
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if onEdit != nil {
                Button("Edit") { onEdit?() }
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

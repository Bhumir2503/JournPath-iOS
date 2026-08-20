import SwiftUI

struct ExpenseSplitSection: View {
    @Environment(ParticipantStore.self) private var participantStore

    @Bindable var vm: ManualExpenseViewModel

    @State private var editingExactFor: String?
    @State private var editingPercentFor: String?

    var body: some View {
        ForEach(participantStore.participants, id: \.id) { participant in
            let uid = participant.id ?? ""

            HStack {
                ParticipantAvatar(participant: participant, size: .small)
                Text(participant.displayName)

                if uid == vm.paidById {
                    Text("paid")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }

                Spacer()

                switch vm.splitType {
                case .equal: equalControl(uid: uid)
                case .exact: exactControl(uid: uid)
                case .percentage: percentControl(uid: uid)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Equal

    @ViewBuilder
    private func equalControl(uid: String) -> some View {
        let isIncluded = vm.equalParticipants.contains(uid)

        Button {
            withAnimation {
                if isIncluded {
                    // Never let the last participant be removed — an empty split
                    // can't satisfy sum(splits) == amountMinor.
                    if vm.equalParticipants.count > 1 {
                        vm.equalParticipants.remove(uid)
                    }
                } else {
                    vm.equalParticipants.insert(uid)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if isIncluded, let share = vm.share(for: uid) {
                    // The real stored value, including the remainder if this
                    // person absorbs it — not total ÷ count.
                    Text(vm.formatted(share))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isIncluded ? Color.brand : Color.gray.opacity(0.3))
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exact

    @ViewBuilder
    private func exactControl(uid: String) -> some View {
        let entered = vm.exactString(for: uid)

        Button {
            editingExactFor = uid
        } label: {
            Text(entered.isEmpty ? "—" : "\(vm.currencySymbol)\(entered)")
                .foregroundStyle(entered.isEmpty ? .secondary : .primary)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: Binding(
            get: { editingExactFor == uid },
            set: { if !$0 { editingExactFor = nil } }
        )) {
            AmountInputView(
                text: Binding(
                    get: { vm.exactString(for: uid) },
                    set: { vm.setExact($0, for: uid) }
                ),
                currency: Binding(get: { vm.selectedCurrency }, set: { _ in }),
                isFixedCurrency: true,
                limit: Double(vm.remainingLimit(excluding: uid))
                    / pow(10, Double(vm.currencyExponent))
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Percentage

    @ViewBuilder
    private func percentControl(uid: String) -> some View {
        let entered = vm.percentString(for: uid)

        Button {
            editingPercentFor = uid
        } label: {
            HStack(spacing: 6) {
                if let share = vm.share(for: uid) {
                    Text(vm.formatted(share))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(entered.isEmpty ? "—" : "\(entered)%")
                    .foregroundStyle(entered.isEmpty ? .secondary : .primary)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: Binding(
            get: { editingPercentFor == uid },
            set: { if !$0 { editingPercentFor = nil } }
        )) {
            PercentageInputView(
                text: Binding(
                    get: { vm.percentString(for: uid) },
                    set: { vm.setPercent($0, for: uid) }
                ),
                limit: vm.remainingPercentLimit(excluding: uid)
            )
            .presentationDetents([.large])
        }
    }
}

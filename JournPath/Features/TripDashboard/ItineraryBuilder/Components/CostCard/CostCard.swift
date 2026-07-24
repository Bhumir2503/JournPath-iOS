import Kingfisher
import SwiftUI

struct CostCard: View {
    let participantManager: ParticipantManager?
    @Binding var info: CostInfo

    @State private var showingAmountSheet = false
    @State var selectedParticipantForAmount: Participant?
    @State var selectedParticipantForPercentage: Participant?

    @State var selectedGuestForAmount: ExpenseGuest?
    @State var selectedGuestForPercentage: ExpenseGuest?

    init(participantManager: ParticipantManager?, info: Binding<CostInfo>) {
        self.participantManager = participantManager
        self._info = info
    }

    var participants: [Participant] {
        participantManager?.sortedParticipants ?? []
    }

    /// Stable identity list used to detect async participant loading.
    var participantIDs: [String] {
        participants.compactMap(\.id)
    }

    var body: some View {
        let hasMultipleParticipants = !participants.isEmpty

        VStack(spacing: 0) {
            ActionRowView(
                icon: "dollarsign.circle.fill",
                title: "Amount",
                value: info.totalAmount.map(formatAmount) ?? "Add amount",
                showDivider: hasMultipleParticipants
            ) {
                showingAmountSheet = true
            }

            if hasMultipleParticipants {
                HStack(spacing: 16) {
                    Image(systemName: "creditcard.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)

                    Text("Paid by")
                        .foregroundStyle(.primary)

                    Spacer()

                    Menu {
                        Picker("Paid by", selection: $info.paidByParticipantId) {
                            ForEach(participants) { participant in
                                if let id = participant.id {
                                    Text(participant.displayName).tag(String?.some(id))
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let selectedId = info.paidByParticipantId,
                                let participant = participants.first(where: { $0.id == selectedId })
                            {
                                AvatarView(name: participant.displayName, color: .primary, imageUrl: participant.photoURL)
                                    .scaleEffect(0.6)
                                    .frame(width: 24, height: 24)

                                Text(participant.displayName)
                            } else {
                                Text("Select")
                            }
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }
                    .tint(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider().padding(.leading, 16)

                HStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)

                    Toggle("Split Expense", isOn: $info.isSplitEnabled.animation())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if info.isSplitEnabled {
                    Divider().padding(.leading, 16)

                    Stepper(value: guestCountBinding, in: 0...10) {
                        HStack(spacing: 16) {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                            Text("Guests (\(info.guests.count))")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    Divider().padding(.leading, 16)

                    Picker("Split Type", selection: $info.splitType) {
                        ForEach(SplitType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider().padding(.leading, 16)

                    VStack(spacing: 0) {
                        ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                            participantRow(participant)

                            if index < participants.count - 1 || !info.guests.isEmpty {
                                Divider().padding(.leading, 56)
                            }
                        }

                        ForEach(Array(info.guests.enumerated()), id: \.element.id) { index, guest in
                            guestRow(for: $info.guests[index])

                            if index < info.guests.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }

                        if let footer = splitStatus {
                            Divider().padding(.leading, 16)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(footer.label)
                                    Spacer()
                                    Text(footer.value)
                                        .monospacedDigit()
                                }

                                if let subLabel = footer.subLabel {
                                    Text(subLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                }
                            }
                            .font(.footnote)
                            .foregroundStyle(footer.isBalanced ? Color.secondary : Color.orange)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .sheet(isPresented: $showingAmountSheet) {
            AmountPicker(amount: $info.totalAmount, currencyCode: $info.currencyCode)
        }
        .sheet(item: $selectedParticipantForAmount) { participant in
            AmountPicker(
                amount: participantAmountBinding(for: participant),
                currencyCode: $info.currencyCode,
                limit: availableAmount(excluding: participant.id)
            )
        }
        .sheet(item: $selectedParticipantForPercentage) { participant in
            PercentagePicker(
                percentage: participantPercentageBinding(for: participant),
                limit: availablePercentage(excluding: participant.id)
            )
        }
        .sheet(item: $selectedGuestForAmount) { guest in
            AmountPicker(
                amount: guestAmountBinding(for: guest),
                currencyCode: $info.currencyCode,
                limit: availableAmount(excluding: guest.id)
            )
        }
        .sheet(item: $selectedGuestForPercentage) { guest in
            PercentagePicker(
                percentage: guestPercentageBinding(for: guest),
                limit: availablePercentage(excluding: guest.id)
            )
        }
        .onChange(of: info.isSplitEnabled) { _, enabled in
            if enabled {
                recomputeSplit()
            }
        }
        .onChange(of: info.splitType) { _, _ in
            recomputeSplit()
        }
        .onChange(of: info.totalAmount) { _, _ in
            recomputeSplit()
        }
        .onChange(of: info.currencyCode) { _, newCode in
            // Snap existing values to the new currency's precision, then
            // recompute so shares still sum exactly to the total (an EUR
            // 3-way split rounded per-share to JPY precision would drift).
            let digits = CurrencyInfo.fractionDigits(for: newCode)
            if let total = info.totalAmount {
                info.totalAmount = total.rounded(toPlaces: digits)
            }
            for (key, value) in info.participantAmounts {
                info.participantAmounts[key] = value.rounded(toPlaces: digits)
            }
            recomputeSplit()
        }
        .onChange(of: participantIDs) { _, _ in
            // Participants load async (cold cache, first launch) and can
            // change while the sheet is open (member added to trip).
            recomputeSplit()
        }
        .onChange(of: info.paidByParticipantId) { _, _ in
            // The payer is the remainder recipient; a payer change can move
            // the odd cent, so recompute computed splits.
            recomputeSplit()
        }
        .onAppear {
            if info.paidByParticipantId == nil {
                info.paidByParticipantId = participantManager?.selfParticipant?.id
            }
        }
        .onChange(of: participantManager?.selfParticipant) { _, newValue in
            if info.paidByParticipantId == nil {
                info.paidByParticipantId = newValue?.id
            }
        }
    }

    // MARK: - Bindings

    var guestCountBinding: Binding<Int> {
        Binding(
            get: { info.guests.count },
            set: { newCount in
                if newCount > info.guests.count {
                    for _ in 0..<(newCount - info.guests.count) {
                        info.guestNameCounter += 1
                        info.guests.append(
                            ExpenseGuest(
                                id: UUID().uuidString,
                                name: "Guest \(info.guestNameCounter)"
                            ))
                    }
                } else if newCount < info.guests.count {
                    for _ in 0..<(info.guests.count - newCount) {
                        let removed = info.guests.removeLast()
                        info.participantAmounts.removeValue(forKey: removed.id)
                        info.participantPercentages.removeValue(forKey: removed.id)
                        info.excludedFromEqualSplit.remove(removed.id)
                    }
                }
                recomputeSplit()
            }
        )
    }

    func participantAmountBinding(for participant: Participant) -> Binding<Double?> {
        Binding(
            get: { participant.id.flatMap { info.participantAmounts[$0] } },
            set: { newValue in
                guard let id = participant.id else { return }
                if let newValue, newValue > 0 {
                    info.participantAmounts[id] = newValue
                } else {
                    info.participantAmounts.removeValue(forKey: id)
                }
            }
        )
    }

    func participantPercentageBinding(for participant: Participant) -> Binding<Double?> {
        Binding(
            get: { participant.id.flatMap { info.participantPercentages[$0] } },
            set: { newValue in
                guard let id = participant.id else { return }
                if let newValue, newValue > 0 {
                    info.participantPercentages[id] = newValue
                } else {
                    info.participantPercentages.removeValue(forKey: id)
                }
                if info.splitType == .percentage {
                    applyPercentageSplit()
                }
            }
        )
    }

    func guestAmountBinding(for guest: ExpenseGuest) -> Binding<Double?> {
        Binding(
            get: { info.participantAmounts[guest.id] },
            set: { newValue in
                if let newValue, newValue > 0 {
                    info.participantAmounts[guest.id] = newValue
                } else {
                    info.participantAmounts.removeValue(forKey: guest.id)
                }
            }
        )
    }

    func guestPercentageBinding(for guest: ExpenseGuest) -> Binding<Double?> {
        Binding(
            get: { info.participantPercentages[guest.id] },
            set: { newValue in
                if let newValue, newValue > 0 {
                    info.participantPercentages[guest.id] = newValue
                } else {
                    info.participantPercentages.removeValue(forKey: guest.id)
                }
                if info.splitType == .percentage {
                    applyPercentageSplit()
                }
            }
        )
    }

    // MARK: - Formatting

    func formatAmount(_ amount: Double) -> String {
        CurrencyFormatterCache.formatter(for: info.currencyCode)
            .string(from: NSNumber(value: amount)) ?? ""
    }
}

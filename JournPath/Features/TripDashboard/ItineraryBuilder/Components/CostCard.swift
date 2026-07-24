import Kingfisher
import SwiftUI

struct CostCard: View {
    let participantManager: ParticipantManager?
    @Binding var info: Expense

    @State private var showingAmountSheet = false
    @State private var selectedParticipantForAmount: Participant?
    @State private var selectedParticipantForPercentage: Participant?

    @State private var selectedGuestForAmount: ExpenseGuest?
    @State private var selectedGuestForPercentage: ExpenseGuest?

    init(participantManager: ParticipantManager?, info: Binding<Expense>) {
        self.participantManager = participantManager
        self._info = info
    }

    private var participants: [Participant] {
        participantManager?.sortedParticipants ?? []
    }

    /// Stable identity list used to detect async participant loading.
    private var participantIDs: [String] {
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

    private var guestCountBinding: Binding<Int> {
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

    private func participantAmountBinding(for participant: Participant) -> Binding<Double?> {
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

    private func participantPercentageBinding(for participant: Participant) -> Binding<Double?> {
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

    private func guestAmountBinding(for guest: ExpenseGuest) -> Binding<Double?> {
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

    private func guestPercentageBinding(for guest: ExpenseGuest) -> Binding<Double?> {
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

    // MARK: - Split logic

    private func availableAmount(excluding id: String?) -> Double? {
        guard let total = info.totalAmount else { return nil }
        guard let excludeId = id else { return total }
        let digits = CurrencyInfo.fractionDigits(for: info.currencyCode)
        let assignedToOthers = info.participantAmounts.filter { $0.key != excludeId }.values.reduce(0, +)
        let remaining = (total - assignedToOthers).rounded(toPlaces: digits)
        return remaining > 0 ? remaining : 0
    }

    private func availablePercentage(excluding id: String?) -> Double {
        guard let excludeId = id else { return 100 }
        let assignedToOthers = info.participantPercentages.filter { $0.key != excludeId }.values.reduce(0, +)
        let remaining = 100 - assignedToOthers
        return remaining > 0 ? remaining : 0
    }

    private func recomputeSplit() {
        guard info.isSplitEnabled else { return }
        switch info.splitType {
        case .evenly:
            applyEqualSplit()
        case .percentage:
            applyPercentageSplit()
        case .manually:
            break
        }
    }

    /// Equal split via integer minor-unit math. The remainder cent goes to
    /// the payer (SplitMath rule), matching serialization and the server.
    private func applyEqualSplit() {
        let allIDs = participantIDs + info.guests.map(\.id)
        guard let total = info.totalAmount, total > 0, !allIDs.isEmpty else { return }

        let includedIDs = allIDs.filter { !info.excludedFromEqualSplit.contains($0) }
        guard !includedIDs.isEmpty else {
            info.participantAmounts = [:]
            return
        }

        let code = info.currencyCode
        let digits = CurrencyInfo.fractionDigits(for: code)
        let totalMinor = CurrencyInfo.minorUnits(total, code: code)

        let shares = SplitMath.equalShares(
            totalMinor: totalMinor,
            includedIDs: includedIDs,
            payerId: info.paidByParticipantId
        )

        info.participantAmounts = shares.mapValues {
            SplitMath.toDisplay($0, fractionDigits: digits)
        }
    }

    /// Percentage split via integer basis points. No float epsilon checks;
    /// "assigned exactly 100%" is the exact integer test totalBp == 10000.
    private func applyPercentageSplit() {
        let allIDs = participantIDs + info.guests.map(\.id)
        guard let total = info.totalAmount, total > 0, !allIDs.isEmpty else { return }

        let code = info.currencyCode
        let digits = CurrencyInfo.fractionDigits(for: code)
        let totalMinor = CurrencyInfo.minorUnits(total, code: code)

        let shares = SplitMath.percentageShares(
            totalMinor: totalMinor,
            percentages: info.participantPercentages,
            orderedIDs: allIDs,
            payerId: info.paidByParticipantId
        )

        info.participantAmounts = shares.mapValues {
            SplitMath.toDisplay($0, fractionDigits: digits)
        }
    }

    private struct SplitStatus {
        let label: String
        let value: String
        let subLabel: String?
        let isBalanced: Bool
    }

    private var splitStatus: SplitStatus? {
        guard let total = info.totalAmount, total > 0 else { return nil }

        // Compare in integer minor units — exact, no float equality risk.
        let code = info.currencyCode
        let digits = CurrencyInfo.fractionDigits(for: code)
        let totalMinor = CurrencyInfo.minorUnits(total, code: code)
        let assignedMinor = info.participantAmounts.values
            .map { CurrencyInfo.minorUnits($0, code: code) }
            .reduce(0, +)
        let remainingMinor = totalMinor - assignedMinor

        if remainingMinor == 0 {
            return SplitStatus(
                label: "Fully assigned",
                value: formatAmount(SplitMath.toDisplay(assignedMinor, fractionDigits: digits)),
                subLabel: nil,
                isBalanced: true
            )
        } else if remainingMinor > 0 {
            var subLabel: String? = nil
            if let payerId = info.paidByParticipantId {
                let name =
                    participants.first(where: { $0.id == payerId })?.displayName
                    ?? info.guests.first(where: { $0.id == payerId })?.name
                    ?? "Payer"
                subLabel = "Will be applied to \(name) when saved"
            }
            return SplitStatus(
                label: "Remaining",
                value: formatAmount(SplitMath.toDisplay(remainingMinor, fractionDigits: digits)),
                subLabel: subLabel,
                isBalanced: false
            )
        } else {
            return SplitStatus(
                label: "Over by",
                value: formatAmount(SplitMath.toDisplay(-remainingMinor, fractionDigits: digits)),
                subLabel: nil,
                isBalanced: false
            )
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func participantRow(_ participant: Participant) -> some View {
        let amount = participant.id.flatMap { info.participantAmounts[$0] }
        let percentage = participant.id.flatMap { info.participantPercentages[$0] }
        let isExcluded = participant.id.flatMap { info.excludedFromEqualSplit.contains($0) } ?? false

        Button {
            if info.splitType == .evenly {
                guard let id = participant.id else { return }
                if info.excludedFromEqualSplit.contains(id) {
                    info.excludedFromEqualSplit.remove(id)
                } else {
                    info.excludedFromEqualSplit.insert(id)
                }
                applyEqualSplit()
            } else if info.splitType == .percentage {
                selectedParticipantForPercentage = participant
            } else {
                selectedParticipantForAmount = participant
            }
        } label: {
            HStack(spacing: 12) {
                if let url = participant.photoURL, let imageURL = URL(string: url) {
                    KFImage(imageURL)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.secondary)
                }

                Text(participant.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                if info.splitType == .percentage {
                    if let pct = percentage {
                        Text("\(String(format: "%.0f", pct))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(Capsule())
                    }
                }

                if info.splitType == .evenly {
                    Text(isExcluded ? "Excluded" : (amount.map(formatAmount) ?? "—"))
                        .font(.subheadline)
                        .foregroundStyle(isExcluded ? Color(UIColor.tertiaryLabel) : .secondary)
                        .monospacedDigit()

                    Image(systemName: isExcluded ? "circle" : "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(isExcluded ? Color(UIColor.tertiaryLabel) : .blue)
                        .padding(.leading, 4)
                } else {
                    Text(amount.map(formatAmount) ?? "Add")
                        .font(.subheadline)
                        .foregroundStyle(amount == nil ? Color(UIColor.tertiaryLabel) : .secondary)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func guestRow(for guestBinding: Binding<ExpenseGuest>) -> some View {
        let guest = guestBinding.wrappedValue
        let amount = info.participantAmounts[guest.id]
        let percentage = info.participantPercentages[guest.id]
        let isExcluded = info.excludedFromEqualSplit.contains(guest.id)

        HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .padding(7)
                .foregroundStyle(.secondary)
                .background(Color(UIColor.tertiarySystemFill))
                .clipShape(Circle())

            TextField("Guest Name", text: guestBinding.name)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 16)

            Button {
                if info.splitType == .evenly {
                    if isExcluded {
                        info.excludedFromEqualSplit.remove(guest.id)
                    } else {
                        info.excludedFromEqualSplit.insert(guest.id)
                    }
                    applyEqualSplit()
                } else if info.splitType == .percentage {
                    selectedGuestForPercentage = guest
                } else {
                    selectedGuestForAmount = guest
                }
            } label: {
                HStack(spacing: 12) {
                    if info.splitType == .percentage {
                        if let pct = percentage {
                            Text("\(String(format: "%.0f", pct))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(UIColor.tertiarySystemFill))
                                .clipShape(Capsule())
                        }
                    }

                    if info.splitType == .evenly {
                        Text(isExcluded ? "Excluded" : (amount.map(formatAmount) ?? "—"))
                            .font(.subheadline)
                            .foregroundStyle(isExcluded ? Color(UIColor.tertiaryLabel) : .secondary)
                            .monospacedDigit()

                        Image(systemName: isExcluded ? "circle" : "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(isExcluded ? Color(UIColor.tertiaryLabel) : .blue)
                            .padding(.leading, 4)
                    } else {
                        Text(amount.map(formatAmount) ?? "Add")
                            .font(.subheadline)
                            .foregroundStyle(amount == nil ? Color(UIColor.tertiaryLabel) : .secondary)
                            .monospacedDigit()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    // MARK: - Formatting

    private func formatAmount(_ amount: Double) -> String {
        CurrencyFormatterCache.formatter(for: info.currencyCode)
            .string(from: NSNumber(value: amount)) ?? ""
    }
}

// MARK: - Formatter cache

/// NumberFormatter creation is expensive; cache one per currency code.
enum CurrencyFormatterCache {
    private static var cache: [String: NumberFormatter] = [:]

    static func formatter(for code: String) -> NumberFormatter {
        if let cached = cache[code] { return cached }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = CurrencyInfo.locale(for: code)
        // The currency's real precision (JPY = 0, BHD = 3), not a hardcoded 2.
        let digits = CurrencyInfo.fractionDigits(for: code)
        formatter.maximumFractionDigits = digits
        formatter.minimumFractionDigits = digits
        cache[code] = formatter
        return formatter
    }
}

// MARK: - Helpers

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

struct ActionRowView: View {
    let icon: String
    let title: String
    let value: String?
    let showDivider: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)

                VStack(spacing: 0) {
                    HStack {
                        Text(title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if let value {
                            Text(value)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 14)

                    if showDivider {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

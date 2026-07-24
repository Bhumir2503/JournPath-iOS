import Kingfisher
import SwiftUI

enum SplitType: String, CaseIterable, Identifiable {
    case evenly = "Evenly"
    case manually = "Manually"
    case percentage = "Percentage"
    var id: String { rawValue }
}

struct ExpenseGuest: Identifiable, Equatable {
    let id: String
    var name: String
}

struct CostCard: View {
    let participantManager: ParticipantManager?
    @AppStorage var currencyCode: String

    @State private var isSplitEnabled = false
    @State private var showingAmountSheet = false
    @State private var participantAmounts: [String: Double] = [:]
    @State private var selectedParticipantForAmount: Participant?
    @State private var selectedParticipantForPercentage: Participant?
    @State private var totalAmount: Double?
    @State private var splitType: SplitType = .evenly
    @State private var participantPercentages: [String: Double] = [:]
    @State private var excludedFromEqualSplit: Set<String> = []
    @State private var paidByParticipantId: String?

    @State private var guests: [ExpenseGuest] = []
    @State private var selectedGuestForAmount: ExpenseGuest?
    @State private var selectedGuestForPercentage: ExpenseGuest?

    init(participantManager: ParticipantManager?) {
        self.participantManager = participantManager
        let tripId = participantManager?.tripId ?? "default"
        self._currencyCode = AppStorage(wrappedValue: "USD", "currencyCode_\(tripId)")
    }

    private var participants: [Participant] {
        participantManager?.sortedParticipants ?? []
    }

    var body: some View {
        let hasMultipleParticipants = !participants.isEmpty

        VStack(spacing: 0) {
            ActionRowView(
                icon: "dollarsign.circle.fill",
                title: "Amount",
                value: totalAmount.map(formatAmount) ?? "Add amount",
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
                        Picker("Paid by", selection: $paidByParticipantId) {
                            ForEach(participants) { participant in
                                if let id = participant.id {
                                    Text(participant.displayName).tag(String?.some(id))
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let selectedId = paidByParticipantId,
                               let participant = participants.first(where: { $0.id == selectedId }) {
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

                    Toggle("Split Expense", isOn: $isSplitEnabled.animation())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if isSplitEnabled {
                    Divider().padding(.leading, 16)
                    
                    Stepper(value: guestCountBinding, in: 0...10) {
                        HStack(spacing: 16) {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                            Text("Guests (\(guests.count))")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    Divider().padding(.leading, 16)
                    
                    Picker("Split Type", selection: $splitType) {
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

                            if index < participants.count - 1 || !guests.isEmpty {
                                Divider().padding(.leading, 56)
                            }
                        }
                        
                        ForEach(Array(guests.enumerated()), id: \.element.id) { index, guest in
                            guestRow(for: $guests[index])

                            if index < guests.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }

                        if let footer = splitStatus {
                            Divider().padding(.leading, 16)
                            HStack {
                                Text(footer.label)
                                Spacer()
                                Text(footer.value)
                                    .monospacedDigit()
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
            AmountPicker(amount: $totalAmount, currencyCode: $currencyCode)
        }
        .sheet(item: $selectedParticipantForAmount) { participant in
            AmountPicker(
                amount: participantAmountBinding(for: participant),
                currencyCode: $currencyCode
            )
        }
        .sheet(item: $selectedParticipantForPercentage) { participant in
            PercentagePicker(
                percentage: participantPercentageBinding(for: participant)
            )
        }
        .sheet(item: $selectedGuestForAmount) { guest in
            AmountPicker(
                amount: guestAmountBinding(for: guest),
                currencyCode: $currencyCode
            )
        }
        .sheet(item: $selectedGuestForPercentage) { guest in
            PercentagePicker(
                percentage: guestPercentageBinding(for: guest)
            )
        }
        .onChange(of: isSplitEnabled) { _, enabled in
            if enabled {
                recomputeSplit()
            }
        }

        .onChange(of: splitType) { _, _ in
            recomputeSplit()
        }
        .onChange(of: totalAmount) { _, _ in
            recomputeSplit()
        }
        .onChange(of: currencyCode) { _, newCode in
            // Round existing amounts to the new currency's precision (e.g. -> JPY).
            let digits = CurrencyInfo.fractionDigits(for: newCode)
            if let total = totalAmount {
                totalAmount = total.rounded(toPlaces: digits)
            }
            for (key, value) in participantAmounts {
                participantAmounts[key] = value.rounded(toPlaces: digits)
            }
        }
        .onAppear {
            if paidByParticipantId == nil {
                paidByParticipantId = participantManager?.selfParticipant?.id
            }
        }
        .onChange(of: participantManager?.selfParticipant) { _, newValue in
            if paidByParticipantId == nil {
                paidByParticipantId = newValue?.id
            }
        }
    }

    // MARK: - Bindings

    private var guestCountBinding: Binding<Int> {
        Binding(
            get: { guests.count },
            set: { newCount in
                if newCount > guests.count {
                    for _ in 0..<(newCount - guests.count) {
                        guests.append(ExpenseGuest(id: UUID().uuidString, name: "Guest \(guests.count + 1)"))
                    }
                } else if newCount < guests.count {
                    for _ in 0..<(guests.count - newCount) {
                        let removed = guests.removeLast()
                        participantAmounts.removeValue(forKey: removed.id)
                        participantPercentages.removeValue(forKey: removed.id)
                        excludedFromEqualSplit.remove(removed.id)
                    }
                }
                recomputeSplit()
            }
        )
    }

    private func participantAmountBinding(for participant: Participant) -> Binding<Double?> {
        Binding(
            get: { participant.id.flatMap { participantAmounts[$0] } },
            set: { newValue in
                guard let id = participant.id else { return }
                if let newValue, newValue > 0 {
                    participantAmounts[id] = newValue
                } else {
                    // Clearing the sheet removes the entry instead of storing 0.
                    participantAmounts.removeValue(forKey: id)
                }
            }
        )
    }

    private func participantPercentageBinding(for participant: Participant) -> Binding<Double?> {
        Binding(
            get: { participant.id.flatMap { participantPercentages[$0] } },
            set: { newValue in
                guard let id = participant.id else { return }
                if let newValue, newValue >= 0 {
                    participantPercentages[id] = newValue
                } else {
                    participantPercentages.removeValue(forKey: id)
                }
                if splitType == .percentage {
                    applyPercentageSplit()
                }
            }
        )
    }

    private func guestAmountBinding(for guest: ExpenseGuest) -> Binding<Double?> {
        Binding(
            get: { participantAmounts[guest.id] },
            set: { newValue in
                if let newValue, newValue > 0 {
                    participantAmounts[guest.id] = newValue
                } else {
                    participantAmounts.removeValue(forKey: guest.id)
                }
            }
        )
    }

    private func guestPercentageBinding(for guest: ExpenseGuest) -> Binding<Double?> {
        Binding(
            get: { participantPercentages[guest.id] },
            set: { newValue in
                if let newValue, newValue >= 0 {
                    participantPercentages[guest.id] = newValue
                } else {
                    participantPercentages.removeValue(forKey: guest.id)
                }
                if splitType == .percentage {
                    applyPercentageSplit()
                }
            }
        )
    }

    // MARK: - Split logic

    private func recomputeSplit() {
        guard isSplitEnabled else { return }
        switch splitType {
        case .evenly:
            applyEqualSplit()
        case .percentage:
            applyPercentageSplit()
        case .manually:
            break
        }
    }

    private func applyPercentageSplit() {
        let allIDs = participants.compactMap(\.id) + guests.map(\.id)
        guard let total = totalAmount, total > 0, !allIDs.isEmpty else { return }

        let digits = CurrencyInfo.fractionDigits(for: currencyCode)
        var amounts: [String: Double] = [:]
        
        var assignedTotal: Double = 0
        var remainingPercentage: Double = 100
        
        for id in allIDs {
            let pct = participantPercentages[id] ?? 0
            
            let share = (total * pct / 100).rounded(toPlaces: digits)
            amounts[id] = share
            assignedTotal += share
            remainingPercentage -= pct
        }

        if abs(remainingPercentage) < 0.01 {
            let remainder = (total - assignedTotal).rounded(toPlaces: digits)
            if remainder != 0, let firstID = allIDs.first {
                amounts[firstID] = (amounts[firstID] ?? 0) + remainder
            }
        }

        participantAmounts = amounts
    }

    private func applyEqualSplit() {
        let allIDs = participants.compactMap(\.id) + guests.map(\.id)
        guard let total = totalAmount, total > 0, !allIDs.isEmpty else { return }

        let includedIDs = allIDs.filter { !excludedFromEqualSplit.contains($0) }
        
        guard !includedIDs.isEmpty else {
            participantAmounts = [:]
            return
        }

        let digits = CurrencyInfo.fractionDigits(for: currencyCode)
        let count = Double(includedIDs.count)
        let share = (total / count).rounded(toPlaces: digits)

        var amounts: [String: Double] = [:]
        for id in includedIDs {
            amounts[id] = share
        }

        // Assign the remainder to the first included participant or guest.
        let remainder = (total - share * count).rounded(toPlaces: digits)
        if remainder != 0, let firstID = includedIDs.first {
            amounts[firstID] = (share + remainder).rounded(toPlaces: digits)
        }

        participantAmounts = amounts
    }

    private struct SplitStatus {
        let label: String
        let value: String
        let isBalanced: Bool
    }

    private var splitStatus: SplitStatus? {
        guard let total = totalAmount, total > 0 else { return nil }

        let digits = CurrencyInfo.fractionDigits(for: currencyCode)
        let assigned = participantAmounts.values.reduce(0, +)
        let remaining = (total - assigned).rounded(toPlaces: digits)

        if remaining == 0 {
            return SplitStatus(label: "Fully assigned", value: formatAmount(assigned), isBalanced: true)
        } else if remaining > 0 {
            return SplitStatus(label: "Remaining", value: formatAmount(remaining), isBalanced: false)
        } else {
            return SplitStatus(label: "Over by", value: formatAmount(-remaining), isBalanced: false)
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func participantRow(_ participant: Participant) -> some View {
        let amount = participant.id.flatMap { participantAmounts[$0] }
        let percentage = participant.id.flatMap { participantPercentages[$0] }
        let isExcluded = participant.id.flatMap { excludedFromEqualSplit.contains($0) } ?? false

        Button {
            if splitType == .evenly {
                guard let id = participant.id else { return }
                if excludedFromEqualSplit.contains(id) {
                    excludedFromEqualSplit.remove(id)
                } else {
                    excludedFromEqualSplit.insert(id)
                }
                applyEqualSplit()
            } else if splitType == .percentage {
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

                if splitType == .percentage {
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

                if splitType == .evenly {
                    Text(isExcluded ? "Excluded" : formatAmount(amount ?? 0))
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
        let amount = participantAmounts[guest.id]
        let percentage = participantPercentages[guest.id]
        let isExcluded = excludedFromEqualSplit.contains(guest.id)

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
                if splitType == .evenly {
                    if isExcluded {
                        excludedFromEqualSplit.remove(guest.id)
                    } else {
                        excludedFromEqualSplit.insert(guest.id)
                    }
                    applyEqualSplit()
                } else if splitType == .percentage {
                    selectedGuestForPercentage = guest
                } else {
                    selectedGuestForAmount = guest
                }
            } label: {
                HStack(spacing: 12) {
                    if splitType == .percentage {
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

                    if splitType == .evenly {
                        Text(isExcluded ? "Excluded" : formatAmount(amount ?? 0))
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
        CurrencyFormatterCache.formatter(for: currencyCode)
            .string(from: NSNumber(value: amount)) ?? ""
    }
}

// MARK: - Formatter cache

/// NumberFormatter creation is expensive; the original code built a new one for
/// every row on every render. Cache one per currency code instead.
enum CurrencyFormatterCache {
    private static var cache: [String: NumberFormatter] = [:]

    static func formatter(for code: String) -> NumberFormatter {
        if let cached = cache[code] { return cached }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = CurrencyInfo.locale(for: code)
        // Use the currency's real precision (JPY = 0, BHD = 3), not a hardcoded 2.
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

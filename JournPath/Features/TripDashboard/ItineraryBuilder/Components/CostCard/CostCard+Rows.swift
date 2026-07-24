import Kingfisher
import SwiftUI

extension CostCard {
    // MARK: - Rows

    @ViewBuilder
    func participantRow(_ participant: Participant) -> some View {
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
    func guestRow(for guestBinding: Binding<ExpenseGuest>) -> some View {
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
}

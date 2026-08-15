import SwiftUI

struct ParticipantLabel: View {
    let participant: Participant
    var isCurrentUser: Bool = false
    var showsRole: Bool = true
    var showsStatus: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Text(participant.displayName)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(participant.status.isGone ? .secondary : .primary)

            if isCurrentUser {
                Text("(you)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let roleBadge {
                Badge(text: roleBadge, isAccented: participant.role == .captain)
            }

            if showsStatus, let statusBadge {
                Badge(text: statusBadge)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var roleBadge: String? {
        guard showsRole, !participant.status.isGone else { return nil }
        guard participant.role != .passenger else { return nil }
        return participant.role.rawValue.capitalized
    }

    private var statusBadge: String? {
        return participant.status.badgeText
    }

    private struct Badge: View {
        let text: String
        var isAccented: Bool = false

        var body: some View {
            Text(text)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .foregroundStyle(isAccented ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .background(
                    isAccented ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.quaternary),
                    in: .capsule
                )
                .fixedSize()
        }
    }
}


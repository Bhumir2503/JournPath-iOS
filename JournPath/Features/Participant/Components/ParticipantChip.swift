import SwiftUI

/// Avatar + name in a capsule. Sizes to its content and flows in a wrapping
/// group, so it's a token you pick from a set — split editor, itinerary
/// attendees. It owns a selected state but never the selection logic.
///
/// Deliberately does not use ParticipantLabel: a role badge inside a capsule
/// looks broken, and role is irrelevant everywhere chips appear.
struct ParticipantChip: View {
    let participant: Participant
    var isSelected: Bool = false
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 6) {
            ParticipantAvatar(
                participant: participant,
                size: .small,
            )
            Text(participant.displayName)
                .font(.subheadline)
                .lineLimit(1)
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        // Tinted fill rather than a solid one: a solid tint swallows the
        // dashed placeholder marker and the avatar's own colour.
        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        .background(
            isSelected ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.quaternary),
            in: .capsule
        )
        .overlay {
            if isSelected {
                Capsule().strokeBorder(.tint, lineWidth: 1)
            }
        }
        .contentShape(.capsule)
    }
}

/// Wrapping group. Selection is a set of document IDs, not of Participants —
/// a listener echo replaces every struct value, so struct equality won't
/// survive a round trip but the ID will.
struct ParticipantChipGroup: View {
    let participants: [Participant]
    var selection: Set<String> = []
    var onTap: ((Participant) -> Void)?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(participants) { participant in
                let id = participant.id ?? ""
                ParticipantChip(
                    participant: participant,
                    isSelected: selection.contains(id),
                    action: onTap.map { handler in { handler(participant) } }
                )
            }
        }
    }
}

/// Minimal wrapping layout — no dependency, replaces the
/// GeometryReader-and-preference-key dance.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let rows = arrange(subviews: subviews, in: width)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, in: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x + size.width > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
                x = 0
            }
            current.indices.append(index)
            current.height = max(current.height, size.height)
            x += size.width + spacing
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

import Kingfisher
import SwiftUI

struct ParticipantAvatar: View {
    let participant: Participant
    var size: Size = .medium

    @Environment(\.displayScale) private var displayScale

    enum Size {
        case small, medium, large
        case custom(CGFloat)

        var dimension: CGFloat {
            switch self {
            case .small: 24
            case .medium: 36
            case .large: 64
            case .custom(let value): value
            }
        }

        var font: Font {
            switch dimension {
            case ..<28: .caption2.weight(.semibold)
            case ..<48: .subheadline.weight(.semibold)
            default: .title2.weight(.semibold)
            }
        }
    }

    var body: some View {
        Group {
            if let url = participant.photo {
                KFImage(url)
                    .setProcessor(
                        DownsamplingImageProcessor(
                            size: CGSize(width: size.dimension * displayScale,
                                         height: size.dimension * displayScale)
                        )
                    )
                    .cacheOriginalImage()
                    .placeholder { initialsView }
                    .fade(duration: 0.15)
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFill()
                    .clipShape(.circle)
            } else {
                initialsView
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .opacity(isDimmed ? 0.55 : 1)
        .accessibilityLabel(accessibilityLabel)
    }

    private var initialsView: some View {
        ZStack {
            Circle().fill(tint)
            Text(participant.initials)
                .font(size.font)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .padding(2)
        }
    }

    private var isDimmed: Bool {
        switch participant.status {
        case .accepted: false
        case .invited, .declined, .left, .kicked: true
        }
    }

    private var accessibilityLabel: String {
        switch participant.status {
        case .accepted: return participant.displayName
        case .invited: return "\(participant.displayName), invited"
        case .declined: return "\(participant.displayName), declined"
        case .left, .kicked: return "\(participant.displayName), no longer on the trip"
        }
    }

    private var tint: Color {
        let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo]
        return palette[Self.stableIndex(for: participant.id ?? "", count: palette.count)]
    }

    static func stableIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let sum = key.utf8.reduce(0) { ($0 + Int($1)) % 100_000 }
        return sum % count
    }
}

// MARK: - Facepile
struct ParticipantFacepile: View {
    let participants: [Participant]
    var maxVisible: Int = 4
    var size: ParticipantAvatar.Size = .custom(28)
    var ringColor: Color = Color(.systemBackground)

    private var visible: [Participant] {
        Array(participants.prefix(maxVisible))
    }

    private var overflow: Int {
        max(0, participants.count - maxVisible)
    }

    var body: some View {
        HStack(spacing: -size.dimension * 0.28) {
            ForEach(visible) { participant in
                ParticipantAvatar(participant: participant, size: size)
                    .overlay(Circle().strokeBorder(ringColor, lineWidth: 2))
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(size.font)
                    .foregroundStyle(.secondary)
                    .frame(width: size.dimension, height: size.dimension)
                    .background(Color(.secondarySystemBackground), in: .circle)
                    .overlay(Circle().strokeBorder(ringColor, lineWidth: 2))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label(for: participants))
    }

    static func label(for participants: [Participant]) -> String {
        switch participants.count {
        case 0: "No one yet"
        case 1: participants[0].displayName
        case 2: "\(participants[0].displayName) and \(participants[1].displayName)"
        default: "\(participants[0].displayName) and \(participants.count - 1) others"
        }
    }
}

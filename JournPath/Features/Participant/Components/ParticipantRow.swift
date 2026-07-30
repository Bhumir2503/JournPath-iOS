import SwiftUI

struct ParticipantRow<Trailing: View>: View {
    let participant: Participant
    var isCurrentUser: Bool = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            ParticipantAvatar(participant: participant)

            VStack(alignment: .leading, spacing: 2) {
                ParticipantLabel(
                    participant: participant,
                    isCurrentUser: isCurrentUser,
                    showsStatus: false
                )

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }

    private var subtitle: String? {
        if let statusSubtitle = participant.status.subtitle { return statusSubtitle }
        return "Joined \(participant.joinedAt.formatted(.dateTime.day().month(.abbreviated)))"
    }
}

extension ParticipantRow where Trailing == EmptyView {
    init(participant: Participant, isCurrentUser: Bool = false, isPlaceholder: Bool = false) {
        self.init(
            participant: participant,
            isCurrentUser: isCurrentUser,
        ) { EmptyView() }
    }
}

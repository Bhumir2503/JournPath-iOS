import SwiftUI

struct PlaceInfoCard: View {
    let infoItems: [(icon: String, text: String, isLink: Bool, action: (() -> Void)?)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(infoItems.enumerated()), id: \.offset) { index, item in
                InfoRowView(
                    icon: item.icon,
                    text: item.text,
                    isLink: item.isLink,
                    showDivider: index < infoItems.count - 1,
                    action: item.action
                )
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct InfoRowView: View {
    let icon: String
    let text: String
    let isLink: Bool
    let showDivider: Bool
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundStyle(isLink ? Color.blue : Color.secondary)
                    .frame(width: 24, height: 24)

                VStack(spacing: 0) {
                    HStack {
                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(isLink ? Color.blue : Color.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.vertical, 14)

                    if showDivider {
                        Divider()
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

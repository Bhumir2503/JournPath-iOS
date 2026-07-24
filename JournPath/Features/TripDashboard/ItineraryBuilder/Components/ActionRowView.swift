import SwiftUI

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

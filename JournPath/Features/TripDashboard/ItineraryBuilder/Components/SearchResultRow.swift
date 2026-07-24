import SwiftUI

struct SearchResultRow: View {
    let result: PlaceResult

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: result.activityDisplay.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(result.activityDisplay.color)
                .frame(width: 32, height: 32)
                .background(result.activityDisplay.color.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body)
                    .foregroundColor(.primary)
                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }
}

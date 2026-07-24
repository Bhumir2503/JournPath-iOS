import SwiftUI

struct CategoryRowBtn: View {
    let category: POICategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(category.color)
                    .frame(width: 32, height: 32)
                    .background(category.color.opacity(0.15))
                    .clipShape(Circle())
                Text(category.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(UIColor.quaternaryLabel))
            }
        }
        .buttonStyle(.plain)
    }
}

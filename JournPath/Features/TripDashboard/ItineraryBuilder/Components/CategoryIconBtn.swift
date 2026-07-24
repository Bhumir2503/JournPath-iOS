import SwiftUI

struct CategoryIconBtn: View {
    let category: POICategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(category.color)
                    .frame(width: 64, height: 64)
                    .background(category.color.opacity(0.15))
                    .clipShape(Circle())
                Text(category.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 74)
            }
        }
        .buttonStyle(.plain)
    }
}

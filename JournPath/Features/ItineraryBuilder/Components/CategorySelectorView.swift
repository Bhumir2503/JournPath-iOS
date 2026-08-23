import MapKit
import SwiftUI

struct CategorySelectorView: View {
    let handleTap: (POICategory) -> Void

    var body: some View {
        List {
            if let firstGroup = categoryGroups.first {
                Section {
                    HStack(spacing: 0) {
                        Spacer()
                        ForEach(firstGroup.items) { category in
                            CategoryIconBtn(category: category) {
                                handleTap(category)
                            }
                            Spacer()
                        }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            ForEach(categoryGroups.dropFirst()) { group in
                Section {
                    ForEach(group.items) { category in
                        CategoryRowBtn(category: category) {
                            handleTap(category)
                        }
                    }
                } header: {
                    Text(group.name)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

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

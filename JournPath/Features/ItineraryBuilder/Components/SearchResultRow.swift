import MapKit
import SwiftUI

struct SearchListView: View {
    let results: [MKMapItem]
    let handleTap: (MKMapItem) -> Void

    var body: some View {
        List {
            ForEach(results, id: \.self) { result in
                SearchResultRow(result: result) { handleTap(result) }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: results.count)
    }
}

struct SearchResultRow: View {
    let result: MKMapItem
    let handleTap: () -> Void

    var body: some View {
        let display = result.pointOfInterestCategory?.activityDisplay ?? .fallback
        Button(action: handleTap) {
            HStack(spacing: 16) {
                Image(systemName: display.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(display.color)
                    .frame(width: 32, height: 32)
                    .background(display.color.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name ?? "Unknown")
                        .font(.body)
                        .foregroundColor(.primary)
                    if let address = result.address?.fullAddress, !address.isEmpty {
                        Text(address)
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
        .buttonStyle(.plain)
    }
}

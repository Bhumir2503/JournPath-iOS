import SwiftUI

struct StorageQuotaBar: View {
    @Environment(TripStore.self) private var tripStore
    @Environment(StorageStore.self) private var storageStore

    private var fraction: Double {
        guard let quota = tripStore.trip?.storageQuota, quota > 0 else { return 0 }
        return min(1, Double(storageStore.usedBytes) / Double(quota))
    }

    private var tint: Color {
        switch fraction {
        case ..<0.75: .accentColor
        case ..<0.95: .orange
        default: .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if fraction >= 0.9 {
                    Label("Almost full", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(tint)
                }
                Spacer()
                Text("\(format(storageStore.usedBytes)) of \(format(tripStore.trip?.storageQuota ?? 10 * 1024 * 1024))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(tint)
                .animation(.easeOut(duration: 0.3), value: fraction)
        }
    }

    private func format(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .binary  // divides by 1024
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

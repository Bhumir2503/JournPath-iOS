import SwiftUI

extension StorageHubView {
    struct QuotaBar: View {
        @Environment(AttachmentManager.self) private var attachmentManager
        @Environment(StorageHubVM.self) private var vm

        var body: some View {
            VStack(spacing: 4) {
                let maxMB = Double(vm.maxStorageBytes) / 1_048_576.0
                let usedMB = min(Double(attachmentManager.totalBytesUsed) / 1_048_576.0, maxMB)

                HStack {
                    Text("Storage Used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f MB / %.1f MB", usedMB, maxMB))
                        .font(.caption)
                        .bold()
                        .foregroundColor(attachmentManager.totalBytesUsed >= vm.maxStorageBytes ? .red : .primary)
                }

                ProgressView(value: min(Double(attachmentManager.totalBytesUsed), Double(vm.maxStorageBytes)), total: Double(vm.maxStorageBytes))
                    .progressViewStyle(.linear)
                    .tint(attachmentManager.totalBytesUsed >= vm.maxStorageBytes ? .red : attachmentManager.totalBytesUsed > vm.maxStorageBytes * 8 / 10 ? .orange : attachmentManager.totalBytesUsed > vm.maxStorageBytes * 5 / 10 ? .yellow : .blue)
            }
            .padding()
        }
    }
}

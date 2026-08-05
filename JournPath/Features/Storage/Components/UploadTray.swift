import SwiftUI

struct UploadTray: View {
    @Environment(SessionStore.self) private var session
    @Environment(StorageStore.self) private var storageStore
    @Environment(UploadManager.self) private var uploads

    private let rowHeight: CGFloat = 50
    private let maxVisibleRows = 3

    private var activeUploads: [StorageFile] {
        storageStore.activeUploads
            .filter { $0.uploadedBy == session.uid }
    }

    private var trayHeight: CGFloat {
        rowHeight * CGFloat(min(activeUploads.count, maxVisibleRows))
    }

    var body: some View {
        Group {
            if !activeUploads.isEmpty {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(activeUploads) { file in
                                UploadRow(
                                    file: file,
                                    progress: file.id.flatMap(uploads.progress(for:)),
                                    onRetry: {},
                                    onCancel: {}
                                )
                                .frame(height: rowHeight)

                                if file.id != activeUploads.last?.id {
                                    Divider().padding(.leading, 46)
                                }
                            }
                        }
                    }
                    .frame(height: trayHeight)
                    .scrollDisabled(activeUploads.count <= maxVisibleRows)
                }
                .background(.ultraThinMaterial)
                .cornerRadius(32)

            }
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.25), value: activeUploads.count)
    }
}

struct UploadRow: View {
    let file: StorageFile
    let progress: Double?
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: file.systemImageName)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(file.originalName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

                switch file.status {
                case .pending:
                    Text("Queued")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                case .uploading:
                    Text("Uploading")
                        .font(.caption2)
                        .foregroundStyle(.blue)

                case .failed:
                    Text(file.quotaRejected ? "Storage full" : "Upload failed")
                        .font(.caption2)
                        .foregroundStyle(.red)

                case .uploaded:
                    EmptyView()
                }
            }

            Spacer()

            trailing
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var trailing: some View {
        switch file.status {
        case .uploading:
            Text(progress.map { "\(Int($0 * 100))%" } ?? "")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

        case .failed where file.quotaRejected:
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

        case .failed:
            Button(action: onRetry) {
                Image(systemName: "arrow.clockwise.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

        case .pending:
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

        case .uploaded:
            EmptyView()
        }
    }
}

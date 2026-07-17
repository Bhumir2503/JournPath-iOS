import SwiftUI

extension StorageHubView {
    struct GridCell: View {
        let attachment: Attachment

        @Environment(StorageHubVM.self) private var vm

        // MARK: - Rename States
        @State private var isRenaming: Bool = false
        @State private var newAttachmentName: String = ""

        // MARK: - Delete States
        @State private var showDeleteConfirmation: Bool = false

        var body: some View {
            Button {
                vm.previewFile(attachment)
            } label: {
                VStack(spacing: 8) {
                    AttachmentThumbnailView(
                        attachmentURL: vm.getLocalURLIfDownloaded(attachment),
                        remoteThumbnailURL: attachment.thumbnailURL.flatMap { URL(string: $0) },
                        size: CGSize(width: 80, height: 80),
                        fallbackIcon: attachment.iconInfo.icon,
                        fallbackColor: attachment.iconInfo.color
                    )
                    .id(vm.downloadedFileIDs.contains(attachment.id ?? ""))
                    .overlay {
                        if vm.downloadingFileId == attachment.id {
                            ZStack {
                                Color.black.opacity(0.4)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                CircularProgressView(progress: vm.downloadProgress, trackColor: .gray, progressColor: .blue)
                            }
                        }
                    }
                    VStack(spacing: 2) {
                        Text((attachment.name as NSString).deletingPathExtension)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Text(attachment.sizeString)
                                .font(.caption2)
                            if vm.getLocalURLIfDownloaded(attachment) == nil {
                                Image(systemName: "icloud")
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 140, alignment: .top)
            .contextMenu {
                        if vm.getLocalURLIfDownloaded(attachment) == nil {
                            Button {
                                vm.downloadFile(attachment)
                            } label: {
                                Label("Download", systemImage: "icloud.and.arrow.down")
                            }
                        } else {
                            Button {
                                vm.removeLocalFile(attachment)
                            } label: {
                                Label("Remove Download", systemImage: "icloud.and.arrow.up")
                            }
                        }

                Button {
                    newAttachmentName = (attachment.name as NSString).deletingPathExtension
                    isRenaming = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .alert("Rename File", isPresented: $isRenaming) {
                TextField("New Name", text: $newAttachmentName)
                Button("Cancel", role: .cancel) {
                    newAttachmentName = ""
                }
                Button("Save") {
                    Task {
                        await vm.renameAttachment(attachment, to: newAttachmentName)
                        newAttachmentName = ""
                        isRenaming = false
                    }
                }
            } message: {
                Text("Enter a new name for your file.")
            }
            .alert("Delete File", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    showDeleteConfirmation = false
                }
                Button("Delete", role: .destructive) {
                    Task {
                        await vm.deleteAttachment(attachment.id)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this file?")
            }
        }
    }
}

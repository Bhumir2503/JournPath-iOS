import Kingfisher
import QuickLook
import SwiftUI

struct StorageFileCell: View {
    @Environment(StorageStore.self) private var storage
    
    let file: StorageFile
    let currentUid: String?
    let progress: Double?
    
    @Binding var isSelecting: Bool
    @Binding var isSelected: Bool

    @State private var isCached = false
    @State private var isDownloading = false
    @State private var previewURL: URL?

    @State private var showRenameAlert = false
    @State private var showDeleteAlert = false
    @State private var newName = ""

    var body: some View {
        Button(action: {
            if isSelecting {
                isSelected.toggle()
            } else {
                if !isCached && !isDownloading && file.status == .uploaded {
                    downloadFile()
                } else if isCached {
                    previewURL = FileDownloadCache.cached(file, tripId: storage.tripId) ?? file.localPath(currentUid: currentUid)
                }
            }
        }) {
            VStack(alignment: .center, spacing: 6) {
                preview
                    .frame(maxWidth: 120, maxHeight: 120)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if isSelecting {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundColor(isSelected ? .blue : .white.opacity(0.8))
                                .shadow(radius: 2)
                                .padding(8)
                        }
                    }
                    .overlay {
                        if isSelecting && isSelected {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(.blue, lineWidth: 3)
                        }
                    }

                VStack(alignment: .center, spacing: 1) {
                    Text(file.originalName)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        if isDownloading {
                            ProgressView().controlSize(.mini)
                        } else if !isCached && file.status == .uploaded {
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        
                        Text(file.displaySize)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                newName = file.originalName
                showRenameAlert = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            if isCached {
                Button(role: .destructive) {
                    FileDownloadCache.remove(file, tripId: storage.tripId)
                    isCached = false
                    previewURL = nil
                } label: {
                    Label("Remove Download", systemImage: "icloud.slash")
                }
            } else if file.status == .uploaded {
                Button {
                    downloadFile()
                } label: {
                    Label("Download", systemImage: "icloud.and.arrow.down")
                }
            }

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Rename File", isPresented: $showRenameAlert) {
            TextField("Name", text: $newName)
            Button("Save") { renameFile() }
                .disabled(newName.isEmpty || newName == file.originalName)
            Button("Cancel", role: .cancel) { }
        }
        .alert("Delete File", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteFile() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this file? This action cannot be undone.")
        }
        .quickLookPreview($previewURL)
        .task(id: file.status) {
            isCached = FileDownloadCache.isCached(file, tripId: storage.tripId, currentUid: currentUid)
        }
    }
    
    private func renameFile() {
        guard let fileId = file.id else { return }
        Task {
            do {
                try await FileService.shared.rename(tripId: storage.tripId, fileId: fileId, newName: newName)
            } catch {
                AppLogger.store.error("Rename failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteFile() {
        guard let fileId = file.id else { return }
        Task {
            do {
                try await FileService.shared.delete(tripId: storage.tripId, fileId: fileId)
            } catch {
                AppLogger.store.error("Delete failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func downloadFile() {
        guard let fileId = file.id else { return }
        isDownloading = true
        Task {
            defer { isDownloading = false }
            do {
                let path = StoragePaths.original(tripId: storage.tripId, fileId: fileId, ext: file.fileExtension)
                let data = try await StorageService.shared.download(path: path)
                let url = try FileDownloadCache.store(data, for: file, tripId: storage.tripId)
                isCached = true
                previewURL = url
            } catch {
                AppLogger.store.error("Download failed: \(error.localizedDescription)")
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            Color(uiColor: .tertiarySystemBackground)

            if let thumbnailURL = file.thumbnailURL {
                KFImage(URL(string: thumbnailURL))
                    .placeholder { placeholderIcon }
                    .resizable()
                    .scaledToFill()
            } else {
                placeholderIcon
            }
        }
        .clipped()
    }

    private var placeholderIcon: some View {
        Image(systemName: file.systemImageName)
            .font(.system(size: 40, weight: .regular))
            .foregroundStyle(.secondary)
    }
}

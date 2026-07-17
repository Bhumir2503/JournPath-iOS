import Combine
import Foundation
import PhotosUI
import SwiftUI
import UIKit

@Observable
class StorageHubVM {
    let tripId: String

    private let attachmentService = AttachmentService()

    var maxStorageBytes: Int64 = 5_242_880

    var errorMessage: String = ""
    var isShowingErrorAlert: Bool = false

    // MARK: - Rename States
    var isRenaming: Bool = false
    var renameId: String?

    // MARK: - Preview and Download States
    var previewURL: URL?
    var downloadingFileId: String?
    var downloadProgress: Double = 0.0
    var downloadedFileIDs: Set<String> = []

    init(tripId: String) {
        self.tripId = tripId
    }
}

extension StorageHubVM {

    func getLocalURLIfDownloaded(_ attachment: Attachment) -> URL? {
        if attachmentService.isFileDownloadedLocally(tripId: tripId, fileId: attachment.id ?? "") {
            return attachmentService.getExistingLocalFileURL(tripId: tripId, fileId: attachment.id ?? "")
        }
        return nil
    }

    func previewFile(_ attachment: Attachment) {
        let fileId = attachment.id ?? ""

        if attachmentService.isFileDownloadedLocally(tripId: tripId, fileId: fileId) {
            self.previewURL = attachmentService.getExistingLocalFileURL(tripId: tripId, fileId: fileId)
        } else {
            performDownload(attachment: attachment, isForPreview: true)
        }
    }

    private func performDownload(attachment: Attachment, isForPreview: Bool) {
        let fileId = attachment.id ?? ""
        let localURL = attachmentService.getLocalFileURL(tripId: tripId, fileId: fileId, fileName: attachment.name)
        
        self.downloadingFileId = fileId
        self.downloadProgress = 0.0

        Task {
            do {
                guard let remoteURL = URL(string: attachment.url) else { throw URLError(.badURL) }
                try await attachmentService.download(url: remoteURL, to: localURL) { progress in
                    DispatchQueue.main.async {
                        self.downloadProgress = progress
                    }
                }

                await MainActor.run {
                    self.downloadingFileId = nil
                    self.downloadProgress = 0.0
                    self.downloadedFileIDs.insert(fileId)
                    if isForPreview {
                        self.previewURL = localURL
                    }
                }
            } catch {
                await MainActor.run {
                    self.downloadingFileId = nil
                    self.downloadProgress = 0.0
                    self.errorMessage = "Failed to download file: \(error.localizedDescription)"
                    self.isShowingErrorAlert = true
                }
            }
        }
    }
}

//ContextMenu
extension StorageHubVM {
    func downloadFile(_ attachment: Attachment) {
        let fileId = attachment.id ?? ""
        if !attachmentService.isFileDownloadedLocally(tripId: tripId, fileId: fileId) {
            performDownload(attachment: attachment, isForPreview: false)
        }
    }

    func removeLocalFile(_ attachment: Attachment) {
        attachmentService.removeLocalDownload(tripId: tripId, fileId: attachment.id ?? "")
        if let id = attachment.id {
            self.downloadedFileIDs.remove(id)
        }
        if let previewURL = self.previewURL, previewURL == attachmentService.getLocalFileURL(tripId: tripId, fileId: attachment.id ?? "", fileName: attachment.name) {
            self.previewURL = nil
        }
    }

    func renameAttachment(_ attachment: Attachment, to newName: String) async {
        guard let attachmentId = attachment.id else { return }
        
        let originalExt = URL(fileURLWithPath: attachment.name).pathExtension
        var finalName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If the user didn't include the original extension, append it back
        if !originalExt.isEmpty {
            let newExt = URL(fileURLWithPath: finalName).pathExtension
            if newExt.lowercased() != originalExt.lowercased() {
                finalName = "\(finalName).\(originalExt)"
            }
        }
        
        guard !finalName.isEmpty else { return }
        
        do {
            try await attachmentService.rename(tripId: tripId, attachmentId: attachmentId, newName: finalName)
        } catch {
            self.errorMessage = "Failed to rename attachment: \(error.localizedDescription)"
            self.isShowingErrorAlert = true
        }
    }

    func deleteAttachment(_ attachmentId: String?) async {
        guard let attachmentId = attachmentId else { return }
        do {
            try await attachmentService.delete(tripId: tripId, attachmentId: attachmentId)
        } catch {
            self.errorMessage = "Failed to delete attachment: \(error.localizedDescription)"
            self.isShowingErrorAlert = true
        }
    }
}

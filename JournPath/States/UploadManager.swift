import Foundation
import PhotosUI
import SwiftUI
import UIKit

enum UploadState: Equatable {
    case pending
    case compressing
    case uploading(progress: Double)
    case generatingThumbnail
    case success
    case error(message: String)
}

struct FileUploadTask: Identifiable, Equatable {
    let id: String
    let tripId: String
    let fileName: String
    var state: UploadState
}

@Observable
class UploadManager {
    var activeTasks: [FileUploadTask] = []

    private let attachmentService = AttachmentService()

    init() {}

    @MainActor
    func uploadFiles(tripId: String, urls: [URL], currentStorage: Int64, maxStorage: Int64) {
        Task {
            var runningStorage = currentStorage

            for url in urls {
                let taskId = UUID().uuidString
                let fileName = url.lastPathComponent

                let newTask = FileUploadTask(id: taskId, tripId: tripId, fileName: fileName, state: .compressing)
                activeTasks.append(newTask)

                do {
                    let (fileData, mimeType) = try await attachmentService.compress(url: url)
                    let size = Int64(fileData.count)
                    
                    if runningStorage >= maxStorage || runningStorage + size > maxStorage {
                        let freeSpace = max(0, maxStorage - runningStorage)
                        let freeMB = Double(freeSpace) / 1_048_576.0
                        let sizeMB = Double(size) / 1_048_576.0
                        
                        let errorMsg = String(format: "File is %.1f MB, but only %.1f MB free.", sizeMB, freeMB)
                        updateTaskState(taskId: taskId, state: .error(message: errorMsg))
                        
                        Task {
                            try? await Task.sleep(nanoseconds: 4_000_000_000)
                            removeTask(taskId: taskId)
                        }
                        continue
                    }
                    
                    runningStorage += size
                    
                    updateTaskState(taskId: taskId, state: .pending)
                    
                    Task {
                        await processUploadData(taskId: taskId, tripId: tripId, url: url, fileName: fileName, fileData: fileData, mimeType: mimeType)
                    }
                } catch {
                    updateTaskState(taskId: taskId, state: .error(message: error.localizedDescription))
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        removeTask(taskId: taskId)
                    }
                }
            }
        }
    }

    private func processUploadData(taskId: String, tripId: String, url: URL, fileName: String, fileData: Data, mimeType: String) async {
        defer {
            let tempDir = FileManager.default.temporaryDirectory
            if url.absoluteString.hasPrefix(tempDir.absoluteString) {
                try? FileManager.default.removeItem(at: url)
            }
        }

        do {
            try await attachmentService.uploadData(tripId: tripId, fileName: fileName, fileData: fileData, mimeType: mimeType) { [weak self] state in
                Task {
                    self?.updateTaskState(taskId: taskId, state: state)
                }
            }

            updateTaskState(taskId: taskId, state: .generatingThumbnail)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            removeTask(taskId: taskId)

        } catch {
            updateTaskState(taskId: taskId, state: .error(message: error.localizedDescription))

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            removeTask(taskId: taskId)
        }
    }
}

// MARK: - Internal helper functions for view updates
extension UploadManager {
    @MainActor
    private func updateTaskState(taskId: String, state: UploadState) {
        if let index = activeTasks.firstIndex(where: { $0.id == taskId }) {
            activeTasks[index].state = state
        }
    }

    @MainActor
    private func removeTask(taskId: String) {
        activeTasks.removeAll(where: { $0.id == taskId })
    }
}

// MARK: - Media picker functions
extension UploadManager {
    @MainActor
    func handleFileImport(tripId: String, result: Result<[URL], Error>, currentStorage: Int64, maxStorage: Int64) throws {
        switch result {
        case .success(let urls):
            uploadFiles(tripId: tripId, urls: urls, currentStorage: currentStorage, maxStorage: maxStorage)
        case .failure(let error):
            throw error
        }
    }

    @MainActor
    func handlePhotoSelection(tripId: String, newItems: [PhotosPickerItem], currentStorage: Int64, maxStorage: Int64, onError: @escaping (Error) -> Void) {
        Task {
            var urls: [URL] = []

            await withTaskGroup(of: URL?.self) { group in
                for item in newItems {
                    group.addTask {
                        if let imageFile = try? await item.loadTransferable(type: ImageFile.self) {
                            return imageFile.fileURL
                        }
                        return nil
                    }
                }

                for await url in group {
                    if let url = url {
                        urls.append(url)
                    }
                }
            }

            if !urls.isEmpty {
                uploadFiles(tripId: tripId, urls: urls, currentStorage: currentStorage, maxStorage: maxStorage)
            }
        }
    }

    @MainActor
    func handleCameraCapture(tripId: String, image: UIImage, currentStorage: Int64, maxStorage: Int64) throws {
        if let data = image.jpegData(compressionQuality: 0.8) {
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "Capture_" + UUID().uuidString.prefix(8) + ".jpg"
            let fileURL = tempDir.appendingPathComponent(fileName)
            do {
                try data.write(to: fileURL)
                uploadFiles(tripId: tripId, urls: [fileURL], currentStorage: currentStorage, maxStorage: maxStorage)
            } catch {
                throw error
            }
        } else {
            throw NSError(domain: "UploadManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to process the camera image."])
        }
    }

    @MainActor
    func processScannedDocuments(tripId: String, images: [UIImage], currentStorage: Int64, maxStorage: Int64) throws {
        var urls: [URL] = []
        for (index, image) in images.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "ScannedDoc_\(UUID().uuidString.prefix(8))_\(index).jpg"
            let fileURL = tempDir.appendingPathComponent(fileName)

            do {
                try imageData.write(to: fileURL)
                urls.append(fileURL)
            } catch {
                AppLogger.managers.error("Failed to save scanned image to temp disk: \(error.localizedDescription)")
            }
        }

        if !urls.isEmpty {
            uploadFiles(tripId: tripId, urls: urls, currentStorage: currentStorage, maxStorage: maxStorage)
        }
    }
}

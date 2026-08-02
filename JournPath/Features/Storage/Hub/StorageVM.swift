import FirebaseAuth
import Foundation
import Observation
import PhotosUI
import SwiftUI

@Observable
@MainActor
final class StorageVM {

    // MARK: - State

    /// Resolved download URLs, keyed by fileId. Cached so each file's
    /// gs:// path is resolved once; Kingfisher handles caching from there.
    private(set) var thumbnails: [String: URL] = [:]

    /// Files currently being compressed and written. Cells for these don't
    /// exist yet, so the count drives a toolbar spinner.
    private(set) var stagingCount = 0

    var errorMessage: String?
    var showingError = false

    var isStaging: Bool { stagingCount > 0 }

    // MARK: - Dependencies

    private let uid: String?
    private let files = FileService.shared
    private let storage = StorageService.shared

    init(uid: String?) {
        self.uid = uid
    }

    // MARK: - Thumbnails

    func thumbnailURL(for file: StorageFile) -> URL? {
        file.id.flatMap { thumbnails[$0] }
    }

    func resolveThumbnails(for storageFiles: [StorageFile]) async {
        for file in storageFiles {
            guard let id = file.id,
                  thumbnails[id] == nil,
                  let path = file.thumbnailPath ?? file.storagePath
            else { continue }

            if let url = try? await storage.downloadURL(for: path) {
                thumbnails[id] = url
            }
        }
    }

    // MARK: - Staging

    /// `.fileImporter` results — security-scoped URLs.
    func stage(_ urls: [URL], tripId: String) {
        Task { await stageAll(tripId: tripId, count: urls.count) { index in
            let url = urls[index]
            return try await Self.offMain { try FileCache.stage(copying: url, kind: .document) }
        }}
    }

    /// PhotosPicker selections.
    func stage(photos: [PhotosPickerItem], tripId: String) async {
        await stageAll(tripId: tripId, count: photos.count) { index in
            let item = photos[index]
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw StagingError.emptyPhoto
            }
            let type = item.supportedContentTypes.first
            let name = "Photo.\(type?.preferredFilenameExtension ?? "jpg")"
            let mime = type?.preferredMIMEType ?? "image/jpeg"
            return try await Self.offMain {
                try FileCache.stage(data: data, originalName: name, mimeType: mime, kind: .photo)
            }
        }
    }

    /// Camera capture. Hand over the least-processed data available —
    /// FileCache downsamples, and pre-compressing here stacks artifacts.
    func stage(image: UIImage, tripId: String) {
        guard let data = image.jpegData(compressionQuality: 1.0) else { return }
        let name = "Photo \(Date.now.formatted(date: .abbreviated, time: .shortened)).jpg"

        Task { await stageAll(tripId: tripId, count: 1) { _ in
            try await Self.offMain {
                try FileCache.stage(data: data, originalName: name,
                                    mimeType: "image/jpeg", kind: .photo)
            }
        }}
    }

    /// Scanner output — pages become one PDF, not N loose images.
    func stage(scan images: [UIImage], tripId: String) {
        let pages = images.compactMap(\.cgImage)
        guard !pages.isEmpty else { return }

        Task { await stageAll(tripId: tripId, count: 1) { _ in
            try await Self.offMain {
                let pdf = try MediaCompressor.makePDF(from: pages)
                return try FileCache.stage(data: pdf, originalName: "Scan.pdf",
                                           mimeType: "application/pdf", kind: .scan)
            }
        }}
    }

    // MARK: - Mutations

//    func retry(_ file: StorageFile, tripId: String) {
//        guard let id = file.id else { return }
//        Task {
//            do { try await files.retry(tripId: tripId, fileId: id) }
//            catch { present(error) }
//        }
//    }
//
//    func delete(_ file: StorageFile, tripId: String) {
//        guard let id = file.id else { return }
//        Task {
//            do { try await files.delete(tripId: tripId, fileId: id) }
//            catch { present(error) }
//        }
//    }

//    func present(_ error: Error) {
//        errorMessage = AnyAppError(error).localizedDescription
//        showingError = true
//    }

    // MARK: - Internals

    /// Stages one file at a time and writes each doc as it completes, so cells
    /// appear progressively rather than all at once after a 10-photo batch.
    /// Hub uploads don't need the atomicity that form saves do.
    private func stageAll(
        tripId: String,
        count: Int,
        produce: (Int) async throws -> PendingFile
    ) async {
        guard let uid else {
            return
        }

        stagingCount += count
        defer { stagingCount = max(0, stagingCount - count) }

        for index in 0..<count {
            do {
                let pending = try await produce(index)
                do {
                    try files.addFiles([pending], tripId: tripId,
                                       parentType: .trip, parentId: tripId, uid: uid)
                } catch {
                    // No doc means nothing will ever claim these bytes.
                    FileCache.discard(pending)
                    throw error
                }
            } catch {
                AppLogger.viewmodel.error("[StorageVM] stageAll: \(error.localizedDescription)")
            }
        }
    }

    /// Compression and file I/O are CPU-bound — keep them off the main actor.
    private static func offMain<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await Task.detached(priority: .userInitiated, operation: work).value
    }

    enum StagingError: LocalizedError {
        case notSignedIn, emptyPhoto

        var errorDescription: String? {
            switch self {
            case .notSignedIn: "You need to be signed in to add files."
            case .emptyPhoto:  "That photo couldn't be loaded."
            }
        }
    }
}

import FirebaseAuth
import Foundation
import Observation
import PhotosUI
import SwiftUI

@Observable
@MainActor
final class StorageVM {

    // MARK: - State

    /// Files being compressed and written. Cells for these don't exist yet,
    /// so the count drives a toolbar spinner.
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

    // MARK: - Staging

    /// `.fileImporter` results — security-scoped URLs.
    func stage(_ urls: [URL], tripId: String, quota: QuotaContext) {
        Task {
            await stageAll(tripId: tripId, count: urls.count, quota: quota) { index in
                let url = urls[index]
                return try await Self.offMain { try FileCache.stage(copying: url, kind: .document) }
            }
        }
    }

    /// PhotosPicker selections.
    func stage(photos: [PhotosPickerItem], tripId: String, quota: QuotaContext) async {
        await stageAll(tripId: tripId, count: photos.count, quota: quota) { index in
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
    func stage(image: UIImage, tripId: String, quota: QuotaContext) {
        guard let data = image.jpegData(compressionQuality: 1.0) else { return }
        let name = "Photo \(Date.now.formatted(date: .abbreviated, time: .shortened)).jpg"

        Task {
            await stageAll(tripId: tripId, count: 1, quota: quota) { _ in
                try await Self.offMain {
                    try FileCache.stage(
                        data: data, originalName: name,
                        mimeType: "image/jpeg", kind: .photo)
                }
            }
        }
    }

    /// Scanner output — pages become one PDF, not N loose images.
    func stage(scan images: [UIImage], tripId: String, quota: QuotaContext) {
        let pages = images.compactMap(\.cgImage)
        guard !pages.isEmpty else { return }

        Task {
            await stageAll(tripId: tripId, count: 1, quota: quota) { _ in
                try await Self.offMain {
                    let pdf = try MediaCompressor.makePDF(from: pages)
                    return try FileCache.stage(
                        data: pdf, originalName: "Scan.pdf",
                        mimeType: "application/pdf", kind: .scan)
                }
            }
        }
    }

    // MARK: - Internals

    /// Stages one file at a time and writes each doc as it completes, so cells
    /// appear progressively rather than after a 10-photo batch finishes.
    /// Hub uploads don't need the atomicity that form saves do.
    private func stageAll(
        tripId: String,
        count: Int,
        quota: QuotaContext,
        produce: (Int) async throws -> PendingFile
    ) async {
        guard let uid else {
            // present(StagingError.notSignedIn)
            return
        }

        stagingCount += count
        defer { stagingCount = max(0, stagingCount - count) }

        // Files staged in this loop haven't round-tripped through the listener
        // yet, so `quota.inFlightBytes` doesn't see them. Track them here or
        // every file in a 20-photo import checks against the same stale number.
        var batchBytes = 0

        for index in 0..<count {
            do {
                let pending = try await produce(index)

                let projected = quota.usedBytes + quota.inFlightBytes + batchBytes + pending.byteSize
                guard projected <= quota.limitBytes else {
                    FileCache.discard(pending)
                    // present(
                    //     StagingError.quotaExceeded(
                    //         remaining: max(0, quota.limitBytes - quota.usedBytes - quota.inFlightBytes - batchBytes)
                    //     ))
                    return  // stop the batch — the rest won't fit either
                }

                do {
                    try files.addFiles(
                        [pending], tripId: tripId,
                        parentType: .trip, parentId: tripId, uid: uid)
                    batchBytes += pending.byteSize
                } catch {
                    // No doc means nothing will ever claim these bytes.
                    FileCache.discard(pending)
                    throw error
                }
            } catch {
                // present(error)  // per-file: one bad pick doesn't kill the rest
            }
        }
    }

    /// Compression and file I/O are CPU-bound — keep them off the main actor.
    private static func offMain<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await Task.detached(priority: .userInitiated, operation: work).value
    }

    // MARK: - Types

    /// A snapshot of the quota at the moment staging begins. Passing values
    /// rather than the stores keeps this VM free of TripStore/StorageStore.
    struct QuotaContext {
        let usedBytes: Int  // server-confirmed
        let inFlightBytes: Int  // committed docs not yet counted
        let limitBytes: Int
    }

    enum StagingError: LocalizedError {
        case notSignedIn
        case emptyPhoto
        case quotaExceeded(remaining: Int)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "You need to be signed in to add files."
            case .emptyPhoto:
                return "That photo couldn't be loaded."
            case .quotaExceeded(let remaining):
                let formatter = ByteCountFormatter()
                formatter.countStyle = .binary
                formatter.allowsNonnumericFormatting = false
                return "This trip is out of storage. Only \(formatter.string(fromByteCount: Int64(remaining))) left."
            }
        }
    }
}

import Foundation
import UniformTypeIdentifiers

/// Staging area for files awaiting upload. Pure functions over the filesystem —
/// no state, nothing injectable, nothing worth faking.
///
/// Threading: synchronous file I/O, and image staging delegates to
/// MediaCompressor. Call from a detached task, never from the main actor.
enum FileUploadCache {

    // MARK: - Configuration

    /// Refuse anything larger. Applied to the source before copying, so a
    /// 2 GB video never lands in Application Support.
    static let maxSourceBytes = 100 * 1_024 * 1_024

    // MARK: - Paths

    static let uploadsDir: URL = {
        var dir = URL.applicationSupportDirectory
            .appending(path: "uploads", directoryHint: .isDirectory)


        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Staged files are transient and re-derivable; keep them out of iCloud.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)

        return dir
    }()

    static func path(for id: String) -> URL {
        uploadsDir.appending(path: "\(id).dat")
    }

    static func exists(_ id: String) -> Bool {
        FileManager.default.fileExists(atPath: path(for: id).path)
    }

    static func byteSize(of id: String) -> Int? {
        try? path(for: id).resourceValues(forKeys: [.fileSizeKey]).fileSize
    }

    // MARK: - Staging

    /// For `.fileImporter` results, which are security-scoped.
    /// Images are downsampled and re-encoded as JPEG; everything else is copied.
    static func stage(copying sourceURL: URL, kind: FileKind) async throws -> PendingFile {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        let sourceSize = (try? sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard sourceSize <= maxSourceBytes else {
            throw CacheError.tooLarge(limit: maxSourceBytes)
        }

        let sourceMime =
            UTType(filenameExtension: sourceURL.pathExtension)?
            .preferredMIMEType ?? "application/octet-stream"

        let id = UUID().uuidString
        let dest = path(for: id)

        let finalMime: String
        if sourceMime.hasPrefix("image/") {
            do {
                try MediaCompressor.downsample(at: sourceURL, to: dest)
                finalMime = "image/jpeg"  // HEIC in, JPEG out
            } catch {
                // Some HEIC variants, animated GIFs, and odd PNGs don't
                // round-trip cleanly. Ship the original rather than dropping
                // the user's file on the floor.
                try FileManager.default.copyItem(at: sourceURL, to: dest)
                finalMime = sourceMime
            }
        } else {
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            finalMime = sourceMime
        }

        return try makePendingFile(
            id: id, dest: dest,
            originalName: sourceURL.lastPathComponent,
            mimeType: finalMime, kind: kind
        )
    }

    /// For camera captures, scans, and PhotosPicker payloads.
    /// Image data is downsampled; PDF and other data is written as-is.
    static func stage(data: Data, originalName: String, mimeType: String, kind: FileKind) async throws -> PendingFile {
        guard data.count <= maxSourceBytes else {
            throw CacheError.tooLarge(limit: maxSourceBytes)
        }

        let id = UUID().uuidString
        let dest = path(for: id)

        let finalMime: String
        if mimeType.hasPrefix("image/") {
            do {
                try MediaCompressor.downsample(data: data, to: dest)
                finalMime = "image/jpeg"
            } catch {
                try data.write(to: dest, options: .atomic)
                finalMime = mimeType
            }
        } else {
            try data.write(to: dest, options: .atomic)
            finalMime = mimeType
        }

        return try makePendingFile(
            id: id, dest: dest, originalName: originalName,
            mimeType: finalMime, kind: kind
        )
    }

    private static func makePendingFile(
        id: String, dest: URL, originalName: String, mimeType: String, kind: FileKind
    ) throws -> PendingFile {
        // Size read *after* compression — this is what actually uploads,
        // what the doc records, and what the cell displays.
        guard let size = try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 else {
            try? FileManager.default.removeItem(at: dest)
            throw CacheError.stagingFailed
        }
        return PendingFile(
            id: id, localPath: dest, originalName: originalName,
            mimeType: mimeType, byteSize: size, kind: kind, pickedAt: .now
        )
    }

    // MARK: - Cleanup

    static func discard(_ file: PendingFile) {
        try? FileManager.default.removeItem(at: file.localPath)
    }

    static func discard(id: String) {
        try? FileManager.default.removeItem(at: path(for: id))
    }

    static func discardAll(_ files: [PendingFile]) {
        files.forEach {
            discard($0)
        }
    }

    /// Total bytes currently staged. Worth surfacing in settings once trips
    /// get long — this directory is invisible to the user otherwise.
    static func totalStagedBytes() -> Int {
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: uploadsDir, includingPropertiesForKeys: [.fileSizeKey]
            )
        else { return 0 }
        return contents.reduce(0) {
            $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    /// Deletes staged bytes that no file doc still needs.
    ///
    /// - Parameter liveIds: every file ID with status pending / uploading /
    ///   failed, across **all** the user's trips. Getting this wrong destroys
    ///   an upload that was only waiting for connectivity, so the caller must
    ///   have loaded the full set before calling — never pass a partial list.
    /// - Parameter graceInterval: files staged more recently than this are
    ///   kept regardless, covering the window between staging and the doc
    ///   being written.
    @discardableResult
    static func pruneOrphans(liveIds: Set<String>, graceInterval: TimeInterval = 3_600) -> Int {
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: uploadsDir, includingPropertiesForKeys: [.contentModificationDateKey]
            )
        else { return 0 }

        let cutoff = Date().addingTimeInterval(-graceInterval)
        var removed = 0

        for url in contents {
            let id = url.deletingPathExtension().lastPathComponent
            guard !liveIds.contains(id) else { continue }

            let modified =
                (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            guard modified < cutoff else { continue }

            try? FileManager.default.removeItem(at: url)
            removed += 1
        }
        return removed
    }

    // MARK: - Errors

    enum CacheError: LocalizedError {
        case tooLarge(limit: Int)
        case stagingFailed

        var errorDescription: String? {
            switch self {
            case .tooLarge(let limit):
                let formatted = ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file)
                return "That file is too large. The limit is \(formatted)."
            case .stagingFailed:
                return "Couldn't prepare that file for upload."
            }
        }
    }
}

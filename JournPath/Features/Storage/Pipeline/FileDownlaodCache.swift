import Foundation

/// Files downloaded for viewing. Distinct from `FileCache`, which stages
/// bytes awaiting upload:
///
/// | | FileCache | FileDownloadCache |
/// |---|---|---|
/// | Location | Application Support | Caches |
/// | Losing it means | user loses their photo | one re-download |
/// | OS can evict | no | yes, and that's fine |
enum FileDownloadCache {

    /// Caches/, not Application Support — the OS may evict these under disk
    /// pressure, which is correct: they're re-downloadable.
    static let root: URL = {
        let dir = URL.cachesDirectory.appending(path: "files", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// One directory per trip so a kick or leave is a single removeItem.
    static func dir(tripId: String) -> URL {
        let dir = root.appending(path: tripId, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func path(tripId: String, fileId: String, ext: String) -> URL {
        dir(tripId: tripId).appending(path: "\(fileId).\(ext)")
    }

    // MARK: - Read / write

    static func isCached(_ file: StorageFile, tripId: String, currentUid: String?) -> Bool {
        guard let id = file.id else { return false }

        // The uploader still has the original staged in FileCache until
        // pruning runs — no reason to re-download their own file.
        if let currentUid, file.uploadedBy == currentUid, FileCache.exists(id) {
            return true
        }

        return cached(file, tripId: tripId) != nil
    }

    static func cached(_ file: StorageFile, tripId: String) -> URL? {
        guard let id = file.id else { return nil }
        let url = path(tripId: tripId, fileId: id, ext: file.fileExtension)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    @discardableResult
    static func store(_ data: Data, for file: StorageFile, tripId: String) throws -> URL {
        guard let id = file.id else { throw CacheError.noId }
        let url = path(tripId: tripId, fileId: id, ext: file.fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Removal

    /// The file doc was deleted. Fires on every member's device via the
    /// listener's `.removed` change, not just the deleter's.
    static func remove(_ file: StorageFile, tripId: String) {
        guard let id = file.id else { return }
        try? FileManager.default.removeItem(
            at: path(tripId: tripId, fileId: id, ext: file.fileExtension)
        )
    }

    /// Extension-agnostic fallback for when the deleted doc can't be decoded
    /// (schema drift on a doc that's going away anyway). Sweeps the trip
    /// directory for anything whose stem matches.
    static func remove(fileId: String, tripId: String) {
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: dir(tripId: tripId), includingPropertiesForKeys: nil
            )
        else { return }

        for url in contents where url.deletingPathExtension().lastPathComponent == fileId {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Eviction

    /// Kicked, left, or the trip was deleted.
    static func purge(tripId: String) {
        try? FileManager.default.removeItem(at: root.appending(path: tripId))
    }

    /// Launch sweep: drop any trip we're no longer a member of. Catches the
    /// case where the kick happened while the app was closed, which is most
    /// of them.
    @discardableResult
    static func purgeAllExcept(tripIds: Set<String>) -> Int {
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil
            )
        else { return 0 }

        var removed = 0
        for url in contents where !tripIds.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
            removed += 1
        }
        return removed
    }

    /// Sign-out on a shared device.
    static func clearAll() {
        try? FileManager.default.removeItem(at: root)
    }

    /// Age-based sweep. Safe to run unconditionally — everything here is
    /// re-downloadable, unlike FileCache where age-based deletion would
    /// destroy an upload that was only waiting for connectivity.
    @discardableResult
    static func evict(olderThan age: TimeInterval = 30 * 86_400) -> Int {
        let cutoff = Date().addingTimeInterval(-age)
        var removed = 0

        guard
            let tripDirs = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil
            )
        else { return 0 }

        for tripDir in tripDirs {
            guard
                let files = try? FileManager.default.contentsOfDirectory(
                    at: tripDir, includingPropertiesForKeys: [.contentAccessDateKey]
                )
            else { continue }

            for file in files {
                // Access date, not modification — a file viewed yesterday
                // should survive even if it was downloaded months ago.
                let accessed =
                    (try? file.resourceValues(forKeys: [.contentAccessDateKey]))?
                    .contentAccessDate ?? .distantPast
                if accessed < cutoff {
                    try? FileManager.default.removeItem(at: file)
                    removed += 1
                }
            }

            // Drop the trip directory if it's now empty.
            if let remaining = try? FileManager.default.contentsOfDirectory(at: tripDir, includingPropertiesForKeys: nil),
                remaining.isEmpty
            {
                try? FileManager.default.removeItem(at: tripDir)
            }
        }
        return removed
    }

    static func totalBytes() -> Int {
        guard
            let enumerator = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.fileSizeKey]
            )
        else { return 0 }

        var total = 0
        for case let url as URL in enumerator {
            total += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return total
    }

    enum CacheError: Error { case noId }
}

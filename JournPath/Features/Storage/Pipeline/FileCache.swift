import Foundation
import UIKit
import UniformTypeIdentifiers

enum FileCache {
    static let uploadsDir: URL = {
        let dir = URL.applicationSupportDirectory.appending(path: "uploads", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var mutable = dir
        var values = URLResourceValues()
        values.isExcludedFromBackup = true  // don't sync staged uploads to iCloud
        try? mutable.setResourceValues(values)
        return dir
    }()

    static func path(for id: String) -> URL {
        uploadsDir.appending(path: "\(id).dat")
    }

    static func exists(_ id: String) -> Bool {
        FileManager.default.fileExists(atPath: path(for: id).path)
    }

    // MARK: - Staging

    /// For .fileImporter results — these are security-scoped.
    static func stage(copying sourceURL: URL, kind: FileKind) throws -> PendingFile {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        let id = UUID().uuidString
        let dest = path(for: id)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: sourceURL, to: dest)

        let size = (try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let type = UTType(filenameExtension: sourceURL.pathExtension)

        return PendingFile(
            id: id,
            localPath: dest,
            originalName: sourceURL.lastPathComponent,
            mimeType: type?.preferredMIMEType ?? "application/octet-stream",
            byteSize: size,
            kind: kind,
            pickedAt: .now
        )
    }

    /// For camera captures, scans, and PhotosPicker payloads.
    static func stage(data: Data, originalName: String, mimeType: String, kind: FileKind) throws -> PendingFile {
        let id = UUID().uuidString
        let dest = path(for: id)
        try data.write(to: dest, options: .atomic)

        return PendingFile(
            id: id, localPath: dest, originalName: originalName,
            mimeType: mimeType, byteSize: data.count, kind: kind, pickedAt: .now
        )
    }

    // MARK: - Cleanup

    static func discard(_ file: PendingFile) {
        try? FileManager.default.removeItem(at: file.localPath)
    }

    static func discard(id: String) {
        try? FileManager.default.removeItem(at: path(for: id))
    }

    /// Called on app launch: drop anything older than a week whose upload
    /// clearly isn't coming back.
    static func pruneOrphans(keepingIds live: Set<String>, olderThan age: TimeInterval = 7 * 86_400) {
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: uploadsDir, includingPropertiesForKeys: [.contentModificationDateKey]
            )
        else { return }

        let cutoff = Date().addingTimeInterval(-age)
        for url in contents {
            let id = url.deletingPathExtension().lastPathComponent
            guard !live.contains(id) else { continue }
            let modified =
                (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            if modified < cutoff { try? FileManager.default.removeItem(at: url) }
        }
    }
}

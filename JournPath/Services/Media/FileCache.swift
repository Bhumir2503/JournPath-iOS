import UniformTypeIdentifiers

enum FileCache {
    static let uploadsDir: URL = {
        let dir = URL.applicationSupportDirectory.appending(path: "uploads", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// For .fileImporter results — these are security-scoped.
    static func stage(copying sourceURL: URL, kind: AttachmentKind) throws -> PendingAttachment {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        let id = UUID().uuidString
        let dest = uploadsDir.appending(path: "\(id).dat")
        try FileManager.default.copyItem(at: sourceURL, to: dest)

        let size = (try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let type = UTType(filenameExtension: sourceURL.pathExtension)

        return PendingAttachment(
            id: id, localPath: dest,
            originalName: sourceURL.lastPathComponent,
            mimeType: type?.preferredMIMEType ?? "application/octet-stream",
            byteSize: size, kind: kind, pickedAt: .now
        )
    }

    /// For camera captures, scans, and PhotosPicker payloads.
    static func stage(data: Data, originalName: String, mimeType: String, kind: AttachmentKind) throws -> PendingAttachment {
        let id = UUID().uuidString
        let dest = uploadsDir.appending(path: "\(id).dat")
        try data.write(to: dest, options: .atomic)

        return PendingAttachment(
            id: id, localPath: dest, originalName: originalName,
            mimeType: mimeType, byteSize: data.count, kind: kind, pickedAt: .now
        )
    }

    static func discard(_ attachment: PendingAttachment) {
        try? FileManager.default.removeItem(at: attachment.localPath)
    }
}

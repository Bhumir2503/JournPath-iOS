import Foundation

enum FileDownloadCache {
    static let dir: URL = {
        // Caches/, not Application Support — the OS may evict these under
        // disk pressure, which is correct: they're re-downloadable.
        var dir = URL.cachesDirectory.appending(path: "files", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func path(for fileId: String, ext: String) -> URL {
        dir.appending(path: "\(fileId).\(ext)")
    }

    static func cached(_ file: StorageFile) -> URL? {
        guard let id = file.id else { return nil }
        let url = path(for: id, ext: file.fileExtension)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func store(_ data: Data, for file: StorageFile) throws -> URL {
        guard let id = file.id else { throw CacheError.noId }
        let url = path(for: id, ext: file.fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }

//    static func evict(olderThan age: TimeInterval = 30 * 86_400) { … }
//    static func totalBytes() -> Int { … }

    enum CacheError: Error { case noId }
}

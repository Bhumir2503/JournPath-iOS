import FirebaseFirestore
import Foundation
import UniformTypeIdentifiers

extension StorageFile {
    var fileExtension: String {
        UTType(mimeType: mimeType)?.preferredFilenameExtension ?? "dat"
    }
    var isImage: Bool { mimeType.hasPrefix("image/") }
    var isReady: Bool { status == .uploaded && storagePath != nil }
    var isInFlight: Bool { status == .pending || status == .uploading }

    /// The uploader still has local bytes for in-flight files.
    var localPath: URL? {
        guard let id, isInFlight, FileCache.exists(id) else { return nil }
        return FileCache.path(for: id)
    }

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file)
    }

    var systemImageName: String {
        if isImage { return "photo" }
        if mimeType == "application/pdf" { return "doc.richtext" }
        switch kind {
        case .scan: return "doc.text.viewfinder"
        case .document, .photo: return "doc.fill"
        }
    }
}

extension PendingFile {
    func makeFileDoc(parentType: ParentType, parentId: String, uid: String) -> [String: Any] {
        [
            "kind": kind.rawValue,
            "originalName": originalName,
            "mimeType": mimeType,
            "byteSize": byteSize,
            "uploadedBy": uid,
            "parentType": parentType.rawValue,
            "parentId": parentId,
            "clientCreatedAt": Timestamp(date: pickedAt),
            "status": FileStatus.pending.rawValue,
            "uploadAttempts": 0,
            "lastError": NSNull(),
            "storagePath": NSNull(),
            "thumbnailPath": NSNull(),
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
    }
}

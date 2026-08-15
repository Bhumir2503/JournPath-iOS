import FirebaseFirestore
import Foundation
import UniformTypeIdentifiers

enum FileKind: String, Codable, Sendable {
    case photo, document, scan
}

/// Lives only in AttachmentsVM while a form is open. Never encoded to Firestore.
struct PendingFile: Identifiable, Hashable, Sendable {
    /// Generated client-side at pick time. Becomes the Firestore doc ID
    /// AND the Storage path segment.
    let id: String

    /// Application Support/uploads/{id}.dat — the only copy of the bytes
    /// until the upload lands.
    let localPath: URL

    let originalName: String  // "IMG_7519.HEIC"
    let mimeType: String  // sniffed at pick time
    let byteSize: Int  // known locally, before upload
    let kind: FileKind
    let pickedAt: Date

    var fileExtension: String {
        UTType(mimeType: mimeType)?.preferredFilenameExtension ?? "dat"
    }
    var isImage: Bool { mimeType.hasPrefix("image/") }

    func makeFileDoc(parentType: ParentType, parentId: String, uid: String) -> [String: Any] {
        [
            "kind": kind.rawValue,
            "originalName": originalName,
            "mimeType": mimeType,
            "byteSize": byteSize,
            "uploadedBy": uid,
            "deviceId": DeviceID.current,
            "parentType": parentType.rawValue,
            "parentId": parentId,
            "clientCreatedAt": Timestamp(date: pickedAt),
            "status": FileStatus.pending.rawValue,
            "quotaRejected": false,
            "uploadAttempts": 0,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
    }
}

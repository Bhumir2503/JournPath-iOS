import FirebaseFirestore
import Foundation
import UniformTypeIdentifiers

enum FileStatus: String, Codable, Sendable {
    case pending, uploading, uploaded, failed
}

enum ParentType: String, Codable, Sendable {
    case trip, itineraryItem, expense
}

enum AttachmentKind: String, Codable, Sendable {
    case photo, document, scan
}

struct StorageFile: Identifiable, Codable, Hashable, Sendable {
    @DocumentID var id: String?

    // ---- Client-owned, written once in the save batch ----
    var kind: AttachmentKind
    var originalName: String
    var mimeType: String
    var byteSize: Int
    var uploadedBy: String
    var parentType: ParentType  // .itineraryItem, .expense, .trip
    var parentId: String
    var clientCreatedAt: Date  // from PendingAttachment.pickedAt
    var deviceId: String

    // ---- Upload state: client writes pending/uploading/failed ----
    var status: FileStatus
    var uploadAttempts: Int
    var lastError: String?

    // ---- Server-owned, written by processUpload ----
    var storagePath: String?
    var originalURL: String?
    var thumbnailPath: String?
    var thumbnailURL: String?
    var width: Int?
    var height: Int?
    var durationSeconds: Double?
    var processedAt: Date?
    var quotaRejected: Bool = false

    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?

    var fileExtension: String {
        UTType(mimeType: mimeType)?.preferredFilenameExtension ?? "dat"
    }
    var isImage: Bool { mimeType.hasPrefix("image/") }
    var isReady: Bool { status == .uploaded && storagePath != nil }
    var isInFlight: Bool { status == .pending || status == .uploading }

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

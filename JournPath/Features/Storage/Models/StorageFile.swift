import FirebaseFirestore
import Foundation

enum FileStatus: String, Codable, Sendable {
    case pending, uploading, uploaded, failed
}

enum ParentType: String, Codable, Sendable {
    case trip, itineraryItem, expense
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
}

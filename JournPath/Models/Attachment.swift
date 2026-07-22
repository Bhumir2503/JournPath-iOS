import CoreTransferable
import FirebaseFirestore
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct Attachment: Identifiable, Hashable, Codable {
    @DocumentID var id: String?

    // Core Metadata
    var tripId: String
    var userId: String
    var name: String
    var fileType: String
    var isPrivate: Bool

    // Storage & Network
    var url: String
    var thumbnailURL: String?
    var storagePath: String
    var sizeBytes: Int64

    // Timestamps & Archiving
    @ServerTimestamp var createdAt: Date?

    init(tripId: String, userId: String, name: String, url: String, thumbnailURL: String? = nil, storagePath: String, sizeBytes: Int64, isPrivate: Bool) {
        self.tripId = tripId
        self.userId = userId
        self.name = name
        self.fileType = URL(fileURLWithPath: name).getFileType()
        self.isPrivate = isPrivate
        self.url = url
        self.thumbnailURL = thumbnailURL 
        self.storagePath = storagePath
        self.sizeBytes = sizeBytes
    }

    var iconInfo: (icon: String, color: Color) {
        switch fileType {
        case "pdf":
            return ("doc", .red)
        case "image":
            return ("photo", .blue)
        case "video":
            return ("video", .purple)
        case "audio":
            return ("audio", .green)
        case "text":
            return ("doc.text", .gray)  // Changed to "doc.text" for a better SF Symbol
        case "spreadsheet":
            return ("chart.bar.doc.fill", .green)  // Changed to a valid SF Symbol
        case "data":
            return ("externaldrive", .gray)  // Changed to a valid SF Symbol
        default:
            return ("doc", .gray)
        }
    }

    var sizeString: String {
        ByteCountFormatter().string(fromByteCount: sizeBytes)
    }
}

// MARK: - Transferable
struct ImageFile: Transferable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .image) { imageFile in
            SentTransferredFile(imageFile.fileURL)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(received.file.lastPathComponent)
            try? FileManager.default.removeItem(at: fileURL)
            try FileManager.default.copyItem(at: received.file, to: fileURL)
            return ImageFile(fileURL: fileURL)
        }
    }
}



import SwiftUI

@Observable
final class AttachmentManager {
    var attachments: [Attachment] = []
    var totalBytesUsed: Int64 = 0

    private var tripId: String
    @ObservationIgnored private let attachmentService = AttachmentService()
    private var cancelListener: (() -> Void)?

    init(tripId: String) {
        self.tripId = tripId
    }

    deinit {
        if cancelListener != nil {
            AppLogger.managers.info("[AttachmentManager.swift] Stopped listening to attachments for trip: \(tripId)")
            cancelListener?()
            cancelListener = nil
        }
    }

    func startListening() {
        guard !tripId.isEmpty else { return }
        guard cancelListener == nil else { return }

        AppLogger.managers.info("[AttachmentManager.swift] Started listening to attachments for trip: \(tripId)")

        cancelListener = attachmentService.listenToAttachments(tripId: tripId) { [weak self] newAttachments in
            guard let self = self else { return }
            self.attachments = newAttachments
            self.totalBytesUsed = newAttachments.reduce(0) { $0 + $1.sizeBytes }
        }
    }

    func stopListening() {
        if cancelListener != nil {
            AppLogger.managers.info("[AttachmentManager.swift] Stopped listening to attachments for trip: \(tripId)")
            cancelListener?()
            cancelListener = nil
        }
    }
}

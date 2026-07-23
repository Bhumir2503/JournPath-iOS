import SwiftUI

@Observable
final class StorageManager {
    var attachments: [Attachment] = []
    var totalBytesUsed: Int64 = 0

    private var tripId: String

    init(tripId: String) {
        self.tripId = tripId
    }

    deinit {

    }

    func startListening() {

    }

    func stopListening() {

    }
}

import AVFoundation
import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main View
struct StorageHubView: View {
    let tripId: String

    init(tripId: String) {
        self.tripId = tripId
    }

    var body: some View {
        NavigationStack {
            VStack {
                QuotaBar()
            }
            .navigationTitle("Storage Hub")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

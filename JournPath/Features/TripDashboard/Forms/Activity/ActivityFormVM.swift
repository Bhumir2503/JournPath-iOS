import FirebaseAuth
import Foundation
import MapKit
import PhotosUI
import SwiftUI

@Observable
@MainActor
final class ActivityFormVM {

    // Variables
    let place: MKMapItem  // passed from itinerary builder
    var activityTitle: String = ""

    // Date Section
    var allDay: Bool = true
    var startDate: Date
    var endDate: Date

    // Cost Section

    // Note Section
    var note: String = ""

    // Storage Section
    var pendingFiles: [PendingFile] = []
    var isStaging: Bool = false
    @ObservationIgnored private let files = FileService.shared

    // Expense Section
    var expenseVM: ManualExpenseViewModel?
    var isExpenseEnabled: Bool = false

    // Service
    let service = ItineraryService()

    init(place: MKMapItem) {
        self.place = place
        self.activityTitle = String(place.name?.prefix(100) ?? "")

        let fallback = Date()

        startDate = fallback
        endDate = fallback.addingTimeInterval(3600)
    }

    func setupExpenseVM(tripId: String, currentUid: String, participantIds: [String]) {
        guard expenseVM == nil else { return }
        expenseVM = ManualExpenseViewModel(tripId: tripId, currentUid: currentUid, participantIds: participantIds)
    }

    // MARK: - Staging Files
    
    func stage(_ urls: [URL]) {
        Task {
            isStaging = true
            defer { isStaging = false }
            for url in urls {
                if let pending = try? await Self.offMain({ try await FileUploadCache.stage(copying: url, kind: .document) }) {
                    pendingFiles.append(pending)
                }
            }
        }
    }

    func stage(photos: [PhotosPickerItem]) async {
        isStaging = true
        defer { isStaging = false }
        for item in photos {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let type = item.supportedContentTypes.first
                let name = "Photo.\(type?.preferredFilenameExtension ?? "jpg")"
                let mime = type?.preferredMIMEType ?? "image/jpeg"
                if let pending = try? await Self.offMain({ try await FileUploadCache.stage(data: data, originalName: name, mimeType: mime, kind: .photo) }) {
                    pendingFiles.append(pending)
                }
            }
        }
    }

    func stage(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 1.0) else { return }
        let name = "Photo \(Date.now.formatted(date: .abbreviated, time: .shortened)).jpg"
        Task {
            isStaging = true
            defer { isStaging = false }
            if let pending = try? await Self.offMain({ try await FileUploadCache.stage(data: data, originalName: name, mimeType: "image/jpeg", kind: .photo) }) {
                pendingFiles.append(pending)
            }
        }
    }

    func stage(scan images: [UIImage]) {
        let pages = images.compactMap(\.cgImage)
        guard !pages.isEmpty else { return }
        Task {
            isStaging = true
            defer { isStaging = false }
            if let pending = try? await Self.offMain({
                let pdf = try await MediaCompressor.makePDF(from: pages)
                return try await FileUploadCache.stage(data: pdf, originalName: "Scan.pdf", mimeType: "application/pdf", kind: .scan)
            }) {
                pendingFiles.append(pending)
            }
        }
    }
    
    private static func offMain<T: Sendable>(
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await Task.detached(priority: .userInitiated) {
            try await work()
        }.value
    }

    func removePendingFile(_ id: String) {
        pendingFiles.removeAll { $0.id == id }
        FileUploadCache.discard(id: id)
    }

    func saveActivity(tripId: String) async -> Bool {
        let item = ItineraryItem.createActivityItem(
            tripId: tripId,
            userId: Auth.auth().currentUser?.uid ?? "",
            title: activityTitle,
            place: place,
            startTime: startDate,
            endTime: endDate,
            allDay: allDay,
            timeZone: place.timeZone!,
            note: note
        )
        do {
            let id = try await service.saveItem(item)
            
            // Attach Files
            if !pendingFiles.isEmpty {
                let uid = Auth.auth().currentUser?.uid ?? ""
                try? files.addFiles(pendingFiles, tripId: tripId, parentType: .itineraryItem, parentId: id, uid: uid)
            }
            
            // Save Expense
            if isExpenseEnabled, let expenseVM = expenseVM, !expenseVM.amountIsEmpty {
                expenseVM.title = activityTitle
                expenseVM.activityId = id
                expenseVM.spentAt = startDate
                _ = expenseVM.save()
            }
            return true
        } catch {
            return false
        }
    }
}

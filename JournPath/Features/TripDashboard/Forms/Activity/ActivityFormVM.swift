import FirebaseAuth
import Foundation
import MapKit
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
    var pendingAttachments: [PendingAttachment] = []

    // Service
    let service = ItineraryService()

    init(place: MKMapItem) {
        self.place = place
        self.activityTitle = String(place.name?.prefix(100) ?? "")

        let fallback = Date()

        startDate = fallback
        endDate = fallback.addingTimeInterval(3600)
    }

    func saveActivity(tripId: String) {
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
        Task {
            try? await service.saveItem(item)
        }
    }
}

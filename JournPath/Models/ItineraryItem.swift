import CoreLocation
import FirebaseFirestore
import Foundation
import MapKit
import SwiftUI



// MARK: - Itinerary Item

enum ItineraryItemType: String, Codable, Hashable {
    case activity
    // flight, lodging, transit added later
}

struct ItineraryItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var tripId: String
    var type: ItineraryItemType

    /// Canonical times — what Firestore indexes and orders by.
    /// `startTime` is a true UTC instant; `timeZoneId` says how to read it.
    var allDay: Bool
    var startTime: Date
    var endTime: Date
    var timeZoneId: String?

    var notes: String?
    var attachments: [String]?

    var activity: ActivityPayload?

    var createdBy: String
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    var version: Int = 1

    static func == (lhs: ItineraryItem, rhs: ItineraryItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    mutating func prepareActivityForSave(
        tripId: String,
        userId: String,
        timeZone: TimeZone,
        placeCalendar: Calendar,
        placeTitle: String,
        mapItem: MKMapItem
    ) {
        self.tripId = tripId
        self.createdBy = userId
        self.timeZoneId = timeZone.identifier

        if self.allDay {
            self.startTime = placeCalendar.startOfDay(for: self.startTime)
            self.endTime = placeCalendar.startOfDay(for: self.endTime)
        }

        let cleanTitle = (self.activity?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.activity?.title = cleanTitle.isEmpty ? placeTitle : cleanTitle
        self.activity?.category = mapToActivityCategory(mapItem.pointOfInterestCategory)
        self.activity?.location = ActivityLocation(mapItem: mapItem)

        if self.notes?.isEmpty == true {
            self.notes = nil
        }
    }
}



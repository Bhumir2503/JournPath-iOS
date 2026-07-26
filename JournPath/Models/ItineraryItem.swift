import CoreLocation
import FirebaseFirestore
import Foundation
import MapKit
import SwiftUI

// MARK: - Itinerary Item

enum ItineraryItemType: String, Codable, Hashable {
    case activity
    case lodging
    // flight, lodging, transit added later
}

struct ItineraryItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var tripId: String
    var type: ItineraryItemType // Activity, Lodging, Flight, Transit

    var allDay: Bool // If true, ignore startTime/endTime
    var startTime: Date // UTC, canonical
    var endTime: Date   // UTC, canonical
    var timeZoneId: String? // IANA timezone, so frontend can interpret locally

    var notes: String? // Quick Notes, max 1000 char
    var attachments: [String]? // Array of Firestore Document IDs that point to file attachments

    var activity: ActivityPayload? // if type is activity

    var createdBy: String // UID of user who created the item
    @ServerTimestamp var createdAt: Date? // Auto-set to server time on create
    @ServerTimestamp var updatedAt: Date? // Auto-set to server time on update
    var version: Int = 1 // Version of the item

    static func == (lhs: ItineraryItem, rhs: ItineraryItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static func createActivityItem(
        tripId: String,
        userId: String,
        title: String,
        place: MKMapItem,
        startTime: Date,
        endTime: Date,
        allDay: Bool,
        timeZone: TimeZone,
        note: String
    ) -> Self {
        let place = ActivityPayload(mapItem: place)
        return ItineraryItem(
            tripId: tripId,
            type: .activity,
            allDay: allDay,
            startTime: startTime,
            endTime: endTime,
            timeZoneId: timeZone.identifier,
            notes: note,
            activity: place,
            createdBy: userId
        )
    }

}

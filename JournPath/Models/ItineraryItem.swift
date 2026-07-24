import CoreLocation
import FirebaseFirestore
import Foundation
import MapKit
import SwiftUI

// MARK: - Coordinates

struct Coords: Codable, Hashable {
    var lat: Double
    var long: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: long)
    }
}

// MARK: - Itinerary Item

enum ItineraryItemType: String, Codable, Hashable {
    case activity
    // flight, lodging, transit added later
}

struct ItineraryItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var tripId: String
    var type: ItineraryItemType
    var addedBy: String
    @ServerTimestamp var createdAt: Date?
    var cost: Double?
    var currency: String?
    var bookingRef: String?
    var notes: String?
    var attachments: [String]?

    /// Canonical times — what Firestore indexes and orders by.
    /// `startTime` is a true UTC instant; `timeZoneId` says how to read it.
    var startTime: Date
    var endTime: Date
    var timeZoneId: String?
    var allDay: Bool

    var activity: ActivityPayload?

    static func == (lhs: ItineraryItem, rhs: ItineraryItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Activity

struct ActivityLocation: Codable, Hashable {
    var name: String
    var address: String
    var phoneNumber: String?
    var coords: Coords?

    init(name: String, address: String, phoneNumber: String? = nil, coords: Coords? = nil) {
        self.name = name
        self.address = address
        self.phoneNumber = phoneNumber
        self.coords = coords
    }

    init(mapItem: MKMapItem) {
        self.name = mapItem.name ?? ""
        self.phoneNumber = mapItem.phoneNumber
        self.address = mapItem.address?.fullAddress ?? ""
        self.coords = Coords(
            lat: mapItem.location.coordinate.latitude,
            long: mapItem.location.coordinate.longitude
        )
    }
}

struct ActivityPayload: Codable, Hashable {
    var title: String
    var category: ActivityCategory?
    var location: ActivityLocation
    var participants: [String]?
}

enum ActivityCategory: String, Codable, CaseIterable {
    case sightseeing, cafe, food, adventure, park, culture, shopping
    case nightlife, entertainment, sports, wellness, education, other

    var icon: String {
        switch self {
        case .sightseeing: "binoculars"
        case .cafe: "cup.and.saucer.fill"
        case .food: "fork.knife"
        case .adventure: "figure.hiking"
        case .park: "tree"
        case .culture: "building.columns"
        case .shopping: "bag"
        case .nightlife: "moon.stars"
        case .entertainment: "clapper.board"
        case .sports: "figure.run"
        case .wellness: "heart.fill"
        case .education: "graduation.cap"
        case .other: "mappin"
        }
    }

    var color: Color {
        switch self {
        case .sightseeing: .cyan
        case .cafe, .food: .orange
        case .adventure: .indigo
        case .park: .green
        case .culture: .purple
        case .shopping: .pink
        case .nightlife, .entertainment: .pink
        case .sports: .indigo
        case .wellness: .red
        case .education: .brown
        case .other: .blue
        }
    }
}

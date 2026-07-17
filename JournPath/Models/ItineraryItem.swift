import CoreLocation
import FirebaseFirestore
import Foundation
import MapKit
import SwiftUI

struct Coords: Codable, Hashable {
    var lat: Double
    var long: Double

    // Computed property for seamless MapKit integration
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: long)
    }
}

struct LocalDateTime: Codable, Hashable {
    var instant: Date  // UTC instant — what Firestore Timestamp actually is
    var timeZoneId: String  // IANA identifier, e.g. "America/New_York", "Europe/Paris"

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneId) ?? .current
    }

    // Formats this moment in ITS OWN timezone, regardless of device location
    func formatted(
        dateStyle: DateFormatter.Style = .medium,
        timeStyle: DateFormatter.Style = .short
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.timeZone = timeZone
        return formatter.string(from: instant)
    }
}

// MARK: Itinerary Items Type
enum ItineraryItemType: String, Codable, Hashable {
    case activity
    case flight
    case lodging
    case transit
}

struct ItineraryItem: Identifiable, Codable {
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

    var startTime: Date  // mirrors activity.startTime / departureTime / checkinDate / departure.time
    var endTime: Date  // mirrors activity.endTime / arrivalTime / checkoutDate / arrival.time
    var timeZoneId: String?

    var activity: ActivityPayload?
    var flight: FlightPayload?
    var stay: StayPayload?
    var transit: TransitPayload?
    
    func formattedTime(_ date: Date, dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        if let tzId = timeZoneId, let tz = TimeZone(identifier: tzId) {
            formatter.timeZone = tz
        }
        return formatter.string(from: date)
    }
}

// MARK: Activity Payload


struct ActivityLocation: Codable {
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
struct ActivityPayload: Codable {
    var title: String
    var category: ActivityCategory?
    var location: ActivityLocation
    var start: LocalDateTime
    var end: LocalDateTime
    var allDay: Bool
    var participants: [String]?
}

enum ActivityCategory: String, Codable, CaseIterable {
    case sightseeing = "sightseeing"
    case cafe = "cafe"
    case food = "food"
    case adventure = "adventure"
    case park = "park"
    case culture = "culture"
    case shopping = "shopping"
    case nightlife = "nightlife"
    case entertainment = "entertainment"
    case sports = "sports"
    case wellness = "wellness"
    case education = "education"
    case other = "other"

    var icon: String {
        switch self {
        case .sightseeing: return "binoculars"
        case .cafe: return "cup.and.saucer.fill"
        case .food: return "fork.knife"
        case .adventure: return "figure.hiking"
        case .park: return "tree"
        case .culture: return "building.columns"
        case .shopping: return "bag"
        case .nightlife: return "moon.stars"
        case .entertainment: return "clapper.board"
        case .sports: return "american.football"
        case .wellness: return "heart.fill"
        case .education: return "graduation.cap"
        case .other: return "mappin"
        }
    }
    
    var color: Color {
        switch self {
        case .sightseeing: return .cyan
        case .cafe, .food: return .orange
        case .adventure: return .indigo
        case .park: return .green
        case .culture: return .purple
        case .shopping: return .pink
        case .nightlife, .entertainment: return .pink
        case .sports: return .indigo
        case .wellness: return .red
        case .education: return .brown
        case .other: return .blue
        }
    }
}

struct FlightAirport: Codable {
    var name: String
    var iata: String
    var icao: String
    var coords: Coords?
    var terminal: String?
    var gate: String?
    var timeZoneId: String
}
struct FlightPayload: Codable {
    var flightId: String
    var flightNumber: String
    var airline: String
    var origin: FlightAirport
    var destination: FlightAirport
    var departure: LocalDateTime
    var arrival: LocalDateTime
    var passengers: [String]
    var seatNumbers: [String: String]

    var flightRef: DocumentReference  // Points to the global flight ref
    var status: String?
    var delayMinutes: Int?
    var actualDeparture: LocalDateTime?
    var actualArrival: LocalDateTime?
}

struct StayPayload: Codable {
    var lodgingName: String
    var address: String
    var roomType: String?
    var checkin: LocalDateTime
    var checkout: LocalDateTime
    var guests: [String]?
    var roomNumbers: [String: String]?

}

// MARK: Transit Payload
enum TransitType: String, Codable {
    case plane = "plane"
    case train = "train"
    case bus = "bus"
    case car = "car"
    case taxi = "taxi"
    case rideshare = "rideshare"
    case walk = "walk"
    case bike = "bike"
    case scooter = "scooter"
    case boat = "boat"
    case other = "other"
}
struct TransitLocation: Codable {
    var name: String
    var address: String
    var coords: Coords? = nil
    var time: LocalDateTime
}
struct TransitPayload: Codable {
    var type: TransitType
    var provider: String?
    var departure: TransitLocation
    var arrival: TransitLocation
    var passengers: [String]?
}

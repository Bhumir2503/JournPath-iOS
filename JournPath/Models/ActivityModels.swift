import CoreLocation
import Foundation
import MapKit
import SwiftUI

struct ActivityPayload: Codable, Hashable {
    var name: String
    var address: String
    var phoneNumber: String?
    var coords: Coords
    var category: ActivityCategory?

    init(name: String, address: String, phoneNumber: String? = nil, coords: Coords) {
        self.name = name
        self.address = address
        self.phoneNumber = phoneNumber
        self.coords = coords
    }

    init(mapItem: MKMapItem) {
        self.name = mapItem.name ?? ""
        self.phoneNumber = mapItem.phoneNumber
        self.address = mapItem.address?.fullAddress ?? ""
        self.category = ActivityCategory.from(mapItem.pointOfInterestCategory)
        self.coords = Coords(
            lat: mapItem.location.coordinate.latitude,
            long: mapItem.location.coordinate.longitude
        )
    }
}

// MARK: - Broad grouping (for filtering / section headers)

/// Coarse buckets used for filtering ("show me all food") and grouping.
/// Kept separate from the granular `ActivityCategory` so display can be
/// specific while filtering stays broad — one source of truth via
/// `ActivityCategory.group`.
enum ActivityGroup: String, Codable, CaseIterable, Sendable {
    case food
    case park
    case culture
    case sightseeing
    case nightlife
    case sports
    case adventure
    case education
    case wellness
    case travel
    case other
}

// MARK: - Granular activity category (Firestore + cross-platform contract)

/// The persisted, platform-neutral category for an itinerary item.
///
/// Raw values are explicit and STABLE — they are written to Firestore and read
/// by both iOS and Android. Never rely on Swift's auto-derived case names here:
/// renaming a case must not change its `rawValue`, or existing documents break.
///
/// This is granular (one case per POI type we surface) so clients can show a
/// precise icon/label. Roll up to a coarse bucket with `.group` when you only
/// need broad filtering.
enum ActivityCategory: String, Codable, CaseIterable, Sendable {

    // Food & Drink
    case restaurant = "restaurant"
    case cafe = "cafe"
    case bakery = "bakery"
    case brewery = "brewery"
    case distillery = "distillery"
    case winery = "winery"
    case foodMarket = "food_market"

    // Parks & Nature
    case nationalPark = "national_park"
    case park = "park"
    case beach = "beach"
    case campground = "campground"

    // Arts & Culture
    case museum = "museum"
    case musicVenue = "music_venue"
    case theater = "theater"
    case landmark = "landmark"
    case monument = "monument"
    case castle = "castle"
    case fortress = "fortress"

    // Sightseeing / Attractions
    case amusementPark = "amusement_park"
    case zoo = "zoo"
    case aquarium = "aquarium"
    case fairground = "fairground"
    case marina = "marina"

    // Entertainment / Nightlife
    case movieTheater = "movie_theater"
    case nightlife = "nightlife"

    // Sports
    case stadium = "stadium"
    case baseball = "baseball"
    case basketball = "basketball"
    case soccer = "soccer"
    case tennis = "tennis"
    case volleyball = "volleyball"
    case golf = "golf"
    case miniGolf = "mini_golf"
    case bowling = "bowling"
    case skating = "skating"
    case skatePark = "skate_park"
    case skiing = "skiing"
    case goKart = "go_kart"

    // Adventure / Water Sports
    case hiking = "hiking"
    case rockClimbing = "rock_climbing"
    case swimming = "swimming"
    case surfing = "surfing"
    case fishing = "fishing"
    case kayaking = "kayaking"

    // Education
    case library = "library"
    case school = "school"
    case university = "university"
    case planetarium = "planetarium"

    // Lodging / Travel
    case lodging = "lodging"

    // Health & Safety
    case hospital = "hospital"
    case pharmacy = "pharmacy"
    case police = "police"
    case fireStation = "fire_station"

    // Fallback for any POI type not surfaced in the app.
    case other = "other"
}

// MARK: - Broad-group rollup

extension ActivityCategory {

    /// The coarse bucket this granular category belongs to.
    var group: ActivityGroup {
        switch self {
        case .restaurant, .cafe, .bakery, .brewery, .distillery, .winery, .foodMarket:
            return .food
        case .nationalPark, .park, .beach, .campground:
            return .park
        case .museum, .musicVenue, .theater, .landmark, .monument, .castle, .fortress:
            return .culture
        case .amusementPark, .zoo, .aquarium, .fairground, .marina:
            return .sightseeing
        case .movieTheater, .nightlife:
            return .nightlife
        case .stadium, .baseball, .basketball, .soccer, .tennis, .volleyball,
            .golf, .miniGolf, .bowling, .skating, .skatePark, .skiing, .goKart:
            return .sports
        case .hiking, .rockClimbing, .swimming, .surfing, .fishing, .kayaking:
            return .adventure
        case .library, .school, .university, .planetarium:
            return .education
        case .lodging:
            return .travel
        case .hospital, .pharmacy, .police, .fireStation:
            return .wellness
        case .other:
            return .other
        }
    }
}

// MARK: - MapKit → ActivityCategory mapping

extension ActivityCategory {

    /// Maps a raw MapKit POI category onto the granular activity taxonomy.
    /// Unlisted MapKit categories (ATM, parking, gas station, …) fall through
    /// to `.other`. Backed by a static dictionary so the mapping is data, not
    /// a giant switch, and stays fast for list rendering.
    static func from(_ mkCategory: MKPointOfInterestCategory?) -> ActivityCategory {
        guard let mkCategory else { return .other }
        return mkMapping[mkCategory] ?? .other
    }

    private static let mkMapping: [MKPointOfInterestCategory: ActivityCategory] = [
        // Food & Drink
        .restaurant: .restaurant,
        .cafe: .cafe,
        .bakery: .bakery,
        .brewery: .brewery,
        .distillery: .distillery,
        .winery: .winery,
        .foodMarket: .foodMarket,

        // Parks & Nature
        .nationalPark: .nationalPark,
        .park: .park,
        .beach: .beach,
        .campground: .campground,

        // Arts & Culture
        .museum: .museum,
        .musicVenue: .musicVenue,
        .theater: .theater,
        .landmark: .landmark,
        .nationalMonument: .monument,
        .castle: .castle,
        .fortress: .fortress,

        // Sightseeing / Attractions
        .amusementPark: .amusementPark,
        .zoo: .zoo,
        .aquarium: .aquarium,
        .fairground: .fairground,
        .marina: .marina,

        // Entertainment / Nightlife
        .movieTheater: .movieTheater,
        .nightlife: .nightlife,

        // Sports
        .stadium: .stadium,
        .baseball: .baseball,
        .basketball: .basketball,
        .soccer: .soccer,
        .tennis: .tennis,
        .volleyball: .volleyball,
        .golf: .golf,
        .miniGolf: .miniGolf,
        .bowling: .bowling,
        .skating: .skating,
        .skatePark: .skatePark,
        .skiing: .skiing,
        .goKart: .goKart,

        // Adventure / Water Sports
        .hiking: .hiking,
        .rockClimbing: .rockClimbing,
        .swimming: .swimming,
        .surfing: .surfing,
        .fishing: .fishing,
        .kayaking: .kayaking,

        // Education
        .library: .library,
        .school: .school,
        .university: .university,
        .planetarium: .planetarium,

        // Lodging
        .hotel: .lodging,

        // Health & Safety
        .hospital: .hospital,
        .pharmacy: .pharmacy,
        .police: .police,
        .fireStation: .fireStation,
    ]
}

// MARK: - Firestore convenience

extension ActivityCategory {
    /// The exact string to persist to Firestore (equal to `rawValue`, named for
    /// intent at call sites).
    var firestoreValue: String { rawValue }

    /// Decode from a stored Firestore string, tolerating unknown/legacy values.
    init(firestoreValue: String?) {
        self = firestoreValue.flatMap(ActivityCategory.init(rawValue:)) ?? .other
    }
}

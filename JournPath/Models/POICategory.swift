import Foundation
import MapKit
import SwiftUI

// MARK: - POI Category

/// A selectable search category backed by MapKit POI filters.
///
/// `color` and `type` are optional at the call site and inherited from the
/// owning `POICategoryGroup` unless a category overrides them (e.g. Lodging).
/// This keeps the data table below free of ~50 repeated `.orange` / `.activity`
/// literals that would otherwise be easy to typo out of sync.
struct POICategory: Hashable, Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let color: Color
    let type: ItineraryItemType
    let poiFilters: [MKPointOfInterestCategory]

    var activityDisplay: ActivityDisplay {
        ActivityDisplay(name: name, icon: icon, color: color)
    }

    // Hash/equate on identity only. `Color` has no well-defined equality, so we
    // deliberately keep it out of the conformance rather than relying on it.
    static func == (lhs: POICategory, rhs: POICategory) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Category Group

struct POICategoryGroup: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let defaultType: ItineraryItemType
    let items: [POICategory]

    /// Builds items, injecting the group's color/type unless the spec overrides.
    init(
        name: String,
        color: Color,
        defaultType: ItineraryItemType = .activity,
        items: [ItemSpec]
    ) {
        self.name = name
        self.color = color
        self.defaultType = defaultType
        self.items = items.map { spec in
            POICategory(
                id: UUID(),
                name: spec.name,
                icon: spec.icon,
                color: spec.color ?? color,
                type: spec.type ?? defaultType,
                poiFilters: spec.filters
            )
        }
    }

    /// Lightweight per-item spec. Only `color`/`type` differ from the group,
    /// and only when explicitly set, so the data table stays terse.
    struct ItemSpec {
        let name: String
        let icon: String
        let filters: [MKPointOfInterestCategory]
        var color: Color? = nil
        var type: ItineraryItemType? = nil

        init(
            _ name: String,
            _ icon: String,
            _ filters: [MKPointOfInterestCategory],
            color: Color? = nil,
            type: ItineraryItemType? = nil
        ) {
            self.name = name
            self.icon = icon
            self.filters = filters
            self.color = color
            self.type = type
        }
    }
}

// MARK: - Category Data

let categoryGroups: [POICategoryGroup] = [
    POICategoryGroup(
        name: "Travel",
        color: .blue,
        items: [
            .init("Restaurants", "fork.knife", [.restaurant], color: .orange),
            .init("Parks", "tree.fill", [.nationalPark, .park], color: .green),
            .init("Landmarks", "camera.fill", [.landmark], color: .purple),
            .init("Lodging", "bed.double.fill", [.hotel], color: .mint, type: .lodging),
        ]
    ),
    POICategoryGroup(
        name: "Food & Drink",
        color: .orange,
        items: [
            .init("Restaurant", "fork.knife", [.restaurant]),
            .init("Cafe", "cup.and.saucer.fill", [.cafe]),
            .init("Bakery", "birthday.cake.fill", [.bakery]),
            .init("Brewery", "mug.fill", [.brewery]),
            .init("Distillery", "drop.fill", [.distillery]),
            .init("Winery", "wineglass.fill", [.winery]),
            .init("Food Market", "basket.fill", [.foodMarket]),
        ]
    ),
    POICategoryGroup(
        name: "Arts & Culture",
        color: .purple,
        items: [
            .init("Museum", "building.columns.fill", [.museum]),
            .init("Concerts", "music.mic", [.musicVenue]),
            .init("Theater", "theatermasks.fill", [.theater]),
            .init("Landmark", "camera.fill", [.landmark]),
            .init("Monument", "building.columns.fill", [.nationalMonument]),
            .init("Castle", "building.fill", [.castle]),
            .init("Fortress", "shield.fill", [.fortress]),
        ]
    ),
    POICategoryGroup(
        name: "Entertainment",
        color: .pink,
        items: [
            .init("Movie Theater", "film.fill", [.movieTheater]),
            .init("Nightlife", "sparkles", [.nightlife]),
        ]
    ),
    POICategoryGroup(
        name: "Parks & Recreation",
        color: .green,
        items: [
            .init("National Park", "tree.fill", [.nationalPark, .park]),
            .init("Beach", "beach.umbrella.fill", [.beach]),
            .init("Campground", "tent.fill", [.campground]),
            .init("Amusement Park", "ticket.fill", [.amusementPark]),
            .init("Zoo", "tortoise.fill", [.zoo]),
            .init("Aquarium", "fish.fill", [.aquarium]),
            .init("Fairground", "flag.fill", [.fairground]),
            .init("Marina", "sailboat.fill", [.marina]),
        ]
    ),
    POICategoryGroup(
        name: "Sports",
        color: .indigo,
        items: [
            .init("Stadium", "sportscourt.fill", [.stadium]),
            .init("Baseball", "figure.baseball", [.baseball]),
            .init("Basketball", "figure.basketball", [.basketball]),
            .init("Soccer", "figure.soccer", [.soccer]),
            .init("Tennis", "figure.tennis", [.tennis]),
            .init("Volleyball", "figure.volleyball", [.volleyball]),
            .init("Golf", "figure.golf", [.golf]),
            .init("Mini Golf", "flag.fill", [.miniGolf]),
            .init("Hiking", "figure.hiking", [.hiking]),
            .init("Rock Climbing", "figure.climbing", [.rockClimbing]),
            .init("Bowling", "figure.bowling", [.bowling]),
            .init("Skating", "figure.ice.skating", [.skating]),
            .init("Skate Park", "figure.skating", [.skatePark]),
            .init("Skiing", "figure.skiing.downhill", [.skiing]),
            .init("Go Kart", "flag.checkered", [.goKart]),
        ]
    ),
    POICategoryGroup(
        name: "Water Sports",
        color: .cyan,
        items: [
            .init("Swimming", "figure.pool.swim", [.swimming]),
            .init("Surfing", "figure.surfing", [.surfing]),
            .init("Fishing", "figure.fishing", [.fishing]),
            .init("Kayaking", "oar.2.crossed", [.kayaking]),
        ]
    ),
    POICategoryGroup(
        name: "Education",
        color: .brown,
        items: [
            .init("Library", "books.vertical.fill", [.library]),
            .init("School", "backpack.fill", [.school]),
            .init("University", "graduationcap.fill", [.university]),
            .init("Planetarium", "moon.stars.fill", [.planetarium]),
        ]
    ),
    POICategoryGroup(
        name: "Health & Safety",
        color: .red,
        items: [
            .init("Hospital", "cross.case.fill", [.hospital]),
            .init("Pharmacy", "pills.fill", [.pharmacy]),
            .init("Police", "shield.fill", [.police]),
            .init("Fire Station", "flame.fill", [.fireStation]),
        ]
    ),
]

import MapKit
import SwiftUI

// MARK: - POI Display Lookup
// Covers ALL MKPointOfInterestCategory values so results never fall back to a generic pin.
// This is separate from categoryGroups which is only for the browsing UI.

extension MKPointOfInterestCategory {
    var activityDisplay: ActivityDisplay {
        switch self {
        // Food & Drink
        case .restaurant: return ActivityDisplay(name: "Restaurant", icon: "fork.knife", color: .orange)
        case .cafe: return ActivityDisplay(name: "Cafe", icon: "cup.and.saucer.fill", color: .orange)
        case .bakery: return ActivityDisplay(name: "Bakery", icon: "birthday.cake.fill", color: .orange)
        case .brewery: return ActivityDisplay(name: "Brewery", icon: "mug.fill", color: .orange)
        case .winery: return ActivityDisplay(name: "Winery", icon: "wineglass.fill", color: .orange)
        case .distillery: return ActivityDisplay(name: "Distillery", icon: "drop.fill", color: .orange)
        case .foodMarket: return ActivityDisplay(name: "Food Market", icon: "basket.fill", color: .orange)
        case .nightlife: return ActivityDisplay(name: "Nightlife", icon: "sparkles", color: .pink)

        // Arts & Culture
        case .museum: return ActivityDisplay(name: "Museum", icon: "building.columns.fill", color: .purple)
        case .musicVenue: return ActivityDisplay(name: "Concert", icon: "music.mic", color: .purple)
        case .theater: return ActivityDisplay(name: "Theater", icon: "theatermasks.fill", color: .purple)
        case .landmark: return ActivityDisplay(name: "Landmark", icon: "camera.fill", color: .purple)
        case .nationalMonument: return ActivityDisplay(name: "Monument", icon: "building.columns.fill", color: .purple)
        case .castle: return ActivityDisplay(name: "Castle", icon: "building.fill", color: .purple)
        case .fortress: return ActivityDisplay(name: "Fortress", icon: "shield.fill", color: .purple)

        // Entertainment
        case .movieTheater: return ActivityDisplay(name: "Movie Theater", icon: "film.fill", color: .pink)
        case .amusementPark: return ActivityDisplay(name: "Amusement Park", icon: "ticket.fill", color: .green)
        case .zoo: return ActivityDisplay(name: "Zoo", icon: "tortoise.fill", color: .green)
        case .aquarium: return ActivityDisplay(name: "Aquarium", icon: "fish.fill", color: .green)
        case .fairground: return ActivityDisplay(name: "Fairground", icon: "flag.fill", color: .green)

        // Parks & Nature
        case .nationalPark: return ActivityDisplay(name: "National Park", icon: "tree.fill", color: .green)
        case .park: return ActivityDisplay(name: "Park", icon: "tree.fill", color: .green)
        case .beach: return ActivityDisplay(name: "Beach", icon: "beach.umbrella.fill", color: .green)
        case .marina: return ActivityDisplay(name: "Marina", icon: "sailboat.fill", color: .green)

        // Lodging
        case .hotel: return ActivityDisplay(name: "Hotel", icon: "bed.double.fill", color: .mint)
        case .campground: return ActivityDisplay(name: "Campground", icon: "tent.fill", color: .green)
        case .rvPark: return ActivityDisplay(name: "RV Park", icon: "car.fill", color: .green)

        // Sports
        case .stadium: return ActivityDisplay(name: "Stadium", icon: "sportscourt.fill", color: .indigo)
        case .baseball: return ActivityDisplay(name: "Baseball", icon: "figure.baseball", color: .indigo)
        case .basketball: return ActivityDisplay(name: "Basketball", icon: "figure.basketball", color: .indigo)
        case .soccer: return ActivityDisplay(name: "Soccer", icon: "figure.soccer", color: .indigo)
        case .tennis: return ActivityDisplay(name: "Tennis", icon: "figure.tennis", color: .indigo)
        case .volleyball: return ActivityDisplay(name: "Volleyball", icon: "figure.volleyball", color: .indigo)
        case .golf: return ActivityDisplay(name: "Golf", icon: "figure.golf", color: .indigo)
        case .miniGolf: return ActivityDisplay(name: "Mini Golf", icon: "flag.fill", color: .indigo)
        case .hiking: return ActivityDisplay(name: "Hiking", icon: "figure.hiking", color: .indigo)
        case .rockClimbing: return ActivityDisplay(name: "Rock Climbing", icon: "figure.climbing", color: .indigo)
        case .bowling: return ActivityDisplay(name: "Bowling", icon: "figure.bowling", color: .indigo)
        case .skating: return ActivityDisplay(name: "Skating", icon: "figure.ice.skating", color: .indigo)
        case .skatePark: return ActivityDisplay(name: "Skate Park", icon: "figure.skating", color: .indigo)
        case .skiing: return ActivityDisplay(name: "Skiing", icon: "figure.skiing.downhill", color: .indigo)
        case .goKart: return ActivityDisplay(name: "Go Kart", icon: "flag.checkered", color: .indigo)
        case .fitnessCenter: return ActivityDisplay(name: "Gym", icon: "dumbbell.fill", color: .indigo)

        // Water Sports
        case .swimming: return ActivityDisplay(name: "Swimming", icon: "figure.pool.swim", color: .cyan)
        case .surfing: return ActivityDisplay(name: "Surfing", icon: "figure.surfing", color: .cyan)
        case .fishing: return ActivityDisplay(name: "Fishing", icon: "figure.fishing", color: .cyan)
        case .kayaking: return ActivityDisplay(name: "Kayaking", icon: "oar.2.crossed", color: .cyan)

        // Education
        case .library: return ActivityDisplay(name: "Library", icon: "books.vertical.fill", color: .brown)
        case .school: return ActivityDisplay(name: "School", icon: "backpack.fill", color: .brown)
        case .university: return ActivityDisplay(name: "University", icon: "graduationcap.fill", color: .brown)
        case .planetarium: return ActivityDisplay(name: "Planetarium", icon: "moon.stars.fill", color: .brown)

        // Health & Safety
        case .hospital: return ActivityDisplay(name: "Hospital", icon: "cross.case.fill", color: .red)
        case .pharmacy: return ActivityDisplay(name: "Pharmacy", icon: "pills.fill", color: .red)
        case .police: return ActivityDisplay(name: "Police", icon: "shield.fill", color: .red)
        case .fireStation: return ActivityDisplay(name: "Fire Station", icon: "flame.fill", color: .red)

        // Personal Services
        case .store: return ActivityDisplay(name: "Shopping", icon: "bag.fill", color: .teal)
        case .bank: return ActivityDisplay(name: "Bank", icon: "building.columns.fill", color: .teal)
        case .atm: return ActivityDisplay(name: "ATM", icon: "dollarsign.circle.fill", color: .teal)
        case .spa: return ActivityDisplay(name: "Spa", icon: "leaf.fill", color: .teal)
        case .laundry: return ActivityDisplay(name: "Laundry", icon: "tshirt.fill", color: .teal)
        case .postOffice: return ActivityDisplay(name: "Post Office", icon: "envelope.fill", color: .teal)
        case .evCharger: return ActivityDisplay(name: "EV Charger", icon: "bolt.car.fill", color: .teal)
        case .restroom: return ActivityDisplay(name: "Restroom", icon: "figure.dress.line.vertical.figure", color: .teal)

        // Transit
        case .airport: return ActivityDisplay(name: "Airport", icon: "airplane", color: .blue)
        case .publicTransport: return ActivityDisplay(name: "Transit", icon: "bus.fill", color: .blue)
        case .parking: return ActivityDisplay(name: "Parking", icon: "p.square.fill", color: .gray)
        case .gasStation: return ActivityDisplay(name: "Gas Station", icon: "fuelpump.fill", color: .gray)
        case .carRental: return ActivityDisplay(name: "Car Rental", icon: "car.2.fill", color: .gray)

        default: return .fallback
        }
    }
}

struct ActivityDisplay: Hashable {
    let name: String
    let icon: String
    let color: Color

    static let fallback = ActivityDisplay(
        name: "Place of Interest",
        icon: "mappin.and.ellipse",
        color: .gray
    )
}

import Foundation
import MapKit
// ActivityDisplay.swift
import SwiftUI

// MARK: - Category Types

// MARK: - POI Category with MapKit Filters
struct POICategory: Hashable, Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let color: Color
    let type: ItineraryItemType
    let poiFilters: [MKPointOfInterestCategory]

    var activityDisplay: ActivityDisplay {
        ActivityDisplay(name: name, icon: icon, color: color)
    }
}

// MARK: - Category Group Model
struct POICategoryGroup: Identifiable {
    let id = UUID()
    let name: String
    let items: [POICategory]
}

// MARK: - Category Data
let categoryGroups: [POICategoryGroup] = [
    POICategoryGroup(
        name: "Travel",
        items: [
            // POICategory(name: "Flights", icon: "airplane", color: .blue, type: .flight, poiFilters: [.airport]),
            POICategory(name: "Restaurants", icon: "fork.knife", color: .orange, type: .activity, poiFilters: [.restaurant]),
            POICategory(name: "Parks", icon: "tree.fill", color: .green, type: .activity, poiFilters: [.nationalPark, .park]),
            POICategory(name: "Landmarks", icon: "camera.fill", color: .purple, type: .activity, poiFilters: [.landmark]),
            // POICategory(name: "Hotels", icon: "bed.double.fill", color: .mint, type: .lodging, poiFilters: [.hotel]),
        ]),

    POICategoryGroup(
        name: "Food & Drink",
        items: [
            POICategory(name: "Restaurant", icon: "fork.knife", color: .orange, type: .activity, poiFilters: [.restaurant]),
            POICategory(name: "Cafe", icon: "cup.and.saucer.fill", color: .orange, type: .activity, poiFilters: [.cafe]),
            POICategory(name: "Bakery", icon: "birthday.cake.fill", color: .orange, type: .activity, poiFilters: [.bakery]),
            POICategory(name: "Brewery", icon: "mug.fill", color: .orange, type: .activity, poiFilters: [.brewery]),
            POICategory(name: "Distillery", icon: "drop.fill", color: .orange, type: .activity, poiFilters: [.distillery]),
            POICategory(name: "Winery", icon: "wineglass.fill", color: .orange, type: .activity, poiFilters: [.winery]),
            POICategory(name: "Food Market", icon: "basket.fill", color: .orange, type: .activity, poiFilters: [.foodMarket]),
        ]),
    POICategoryGroup(
        name: "Arts & Culture",
        items: [
            POICategory(name: "Museum", icon: "building.columns.fill", color: .purple, type: .activity, poiFilters: [.museum]),
            POICategory(name: "Concerts", icon: "music.mic", color: .purple, type: .activity, poiFilters: [.musicVenue]),
            POICategory(name: "Theater", icon: "theatermasks.fill", color: .purple, type: .activity, poiFilters: [.theater]),
            POICategory(name: "Landmark", icon: "camera.fill", color: .purple, type: .activity, poiFilters: [.landmark]),
            POICategory(name: "Monument", icon: "building.columns.fill", color: .purple, type: .activity, poiFilters: [.nationalMonument]),
            POICategory(name: "Castle", icon: "building.fill", color: .purple, type: .activity, poiFilters: [.castle]),
            POICategory(name: "Fortress", icon: "shield.fill", color: .purple, type: .activity, poiFilters: [.fortress]),
        ]),
    POICategoryGroup(
        name: "Entertainment",
        items: [
            POICategory(name: "Movie Theater", icon: "film.fill", color: .pink, type: .activity, poiFilters: [.movieTheater]),
            POICategory(name: "Nightlife", icon: "sparkles", color: .pink, type: .activity, poiFilters: [.nightlife]),
        ]),
    POICategoryGroup(
        name: "Parks & Recreation",
        items: [
            POICategory(name: "National Park", icon: "tree.fill", color: .green, type: .activity, poiFilters: [.nationalPark, .park]),
            POICategory(name: "Beach", icon: "beach.umbrella.fill", color: .green, type: .activity, poiFilters: [.beach]),
            // POICategory(name: "Campground", icon: "tent.fill", color: .green, type: .lodging, poiFilters: [.campground]),
            // POICategory(name: "RV Park", icon: "car.fill", color: .green, type: .lodging, poiFilters: [.rvPark]),
            POICategory(name: "Amusement Park", icon: "ticket.fill", color: .green, type: .activity, poiFilters: [.amusementPark]),
            POICategory(name: "Zoo", icon: "tortoise.fill", color: .green, type: .activity, poiFilters: [.zoo]),
            POICategory(name: "Aquarium", icon: "fish.fill", color: .green, type: .activity, poiFilters: [.aquarium]),
            POICategory(name: "Fairground", icon: "flag.fill", color: .green, type: .activity, poiFilters: [.fairground]),
            POICategory(name: "Marina", icon: "sailboat.fill", color: .green, type: .activity, poiFilters: [.marina]),
        ]),
    POICategoryGroup(
        name: "Sports",
        items: [
            POICategory(name: "Stadium", icon: "sportscourt.fill", color: .indigo, type: .activity, poiFilters: [.stadium]),
            POICategory(name: "Baseball", icon: "figure.baseball", color: .indigo, type: .activity, poiFilters: [.baseball]),
            POICategory(name: "Basketball", icon: "figure.basketball", color: .indigo, type: .activity, poiFilters: [.basketball]),
            POICategory(name: "Soccer", icon: "figure.soccer", color: .indigo, type: .activity, poiFilters: [.soccer]),
            POICategory(name: "Tennis", icon: "figure.tennis", color: .indigo, type: .activity, poiFilters: [.tennis]),
            POICategory(name: "Volleyball", icon: "figure.volleyball", color: .indigo, type: .activity, poiFilters: [.volleyball]),
            POICategory(name: "Golf", icon: "figure.golf", color: .indigo, type: .activity, poiFilters: [.golf]),
            POICategory(name: "Mini Golf", icon: "flag.fill", color: .indigo, type: .activity, poiFilters: [.miniGolf]),
            POICategory(name: "Hiking", icon: "figure.hiking", color: .indigo, type: .activity, poiFilters: [.hiking]),
            POICategory(name: "Rock Climbing", icon: "figure.climbing", color: .indigo, type: .activity, poiFilters: [.rockClimbing]),
            POICategory(name: "Bowling", icon: "figure.bowling", color: .indigo, type: .activity, poiFilters: [.bowling]),
            POICategory(name: "Skating", icon: "figure.ice.skating", color: .indigo, type: .activity, poiFilters: [.skating]),
            POICategory(name: "Skate Park", icon: "figure.skating", color: .indigo, type: .activity, poiFilters: [.skatePark]),
            POICategory(name: "Skiing", icon: "figure.skiing.downhill", color: .indigo, type: .activity, poiFilters: [.skiing]),
            POICategory(name: "Go Kart", icon: "flag.checkered", color: .indigo, type: .activity, poiFilters: [.goKart]),
        ]),
    POICategoryGroup(
        name: "Water Sports",
        items: [
            POICategory(name: "Swimming", icon: "figure.pool.swim", color: .cyan, type: .activity, poiFilters: [.swimming]),
            POICategory(name: "Surfing", icon: "figure.surfing", color: .cyan, type: .activity, poiFilters: [.surfing]),
            POICategory(name: "Fishing", icon: "figure.fishing", color: .cyan, type: .activity, poiFilters: [.fishing]),
            POICategory(name: "Kayaking", icon: "oar.2.crossed", color: .cyan, type: .activity, poiFilters: [.kayaking]),
        ]),
    POICategoryGroup(
        name: "Education",
        items: [
            POICategory(name: "Library", icon: "books.vertical.fill", color: .brown, type: .activity, poiFilters: [.library]),
            POICategory(name: "School", icon: "backpack.fill", color: .brown, type: .activity, poiFilters: [.school]),
            POICategory(name: "University", icon: "graduationcap.fill", color: .brown, type: .activity, poiFilters: [.university]),
            POICategory(name: "Planetarium", icon: "moon.stars.fill", color: .brown, type: .activity, poiFilters: [.planetarium]),
        ]),
    POICategoryGroup(
        name: "Health & Safety",
        items: [
            POICategory(name: "Hospital", icon: "cross.case.fill", color: .red, type: .activity, poiFilters: [.hospital]),
            POICategory(name: "Pharmacy", icon: "pills.fill", color: .red, type: .activity, poiFilters: [.pharmacy]),
            POICategory(name: "Police", icon: "shield.fill", color: .red, type: .activity, poiFilters: [.police]),
            POICategory(name: "Fire Station", icon: "flame.fill", color: .red, type: .activity, poiFilters: [.fireStation]),
        ]),
]

// MARK: - Helper Functions
func mapToActivityCategory(_ mkCategory: MKPointOfInterestCategory?) -> ActivityCategory {
    guard let mkCategory = mkCategory else { return .other }
    
    switch mkCategory {
    case .restaurant, .bakery, .brewery, .cafe, .foodMarket, .winery, .distillery:
        return .food
    case .nationalPark, .park, .beach:
        return .park
    case .museum, .nationalMonument, .landmark, .castle, .fortress, .theater:
        return .culture
    case .amusementPark, .zoo, .aquarium, .marina:
        return .sightseeing
    case .movieTheater, .nightlife, .musicVenue:
        return .nightlife
    case .stadium, .baseball, .basketball, .soccer, .tennis, .volleyball, .golf, .miniGolf, .bowling, .skating, .skatePark, .skiing, .goKart:
        return .sports
    case .swimming, .surfing, .fishing, .kayaking, .rockClimbing, .hiking:
        return .adventure
    case .library, .school, .university, .planetarium:
        return .education
    case .hospital, .pharmacy, .police, .fireStation:
        return .wellness
    case .store, .postOffice, .bank, .atm, .evCharger, .gasStation, .parking, .carRental, .laundry, .restroom:
        return .other
    default:
        return .other
    }
}

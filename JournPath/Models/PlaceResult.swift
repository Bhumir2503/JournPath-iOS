import Foundation
import MapKit
import SwiftUI

// MARK: - Core Models

struct SearchNearLocation: Codable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct PlaceResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D?  // not Hashable, excluded below
    let mapItem: MKMapItem?

    // Equality and hashing via id only — coordinate isn't Hashable
    static func == (lhs: PlaceResult, rhs: PlaceResult) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension PlaceResult {
    var activityDisplay: ActivityDisplay {
        mapItem?.pointOfInterestCategory?.activityDisplay ?? .fallback
    }
}

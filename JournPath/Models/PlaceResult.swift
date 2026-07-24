import CoreLocation
import Foundation
import MapKit

struct SearchNearLocation: Codable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct PlaceResult: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D?
    let mapItem: MKMapItem?

    /// Resolved before navigation so the form's pickers can pin to it.
    var timeZone: TimeZone?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        coordinate: CLLocationCoordinate2D?,
        mapItem: MKMapItem?,
        timeZone: TimeZone? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.mapItem = mapItem
        self.timeZone = timeZone
    }

    // Identity only — CLLocationCoordinate2D and MKMapItem aren't Hashable.
    static func == (lhs: PlaceResult, rhs: PlaceResult) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension PlaceResult {
    var activityDisplay: ActivityDisplay {
        mapItem?.pointOfInterestCategory?.activityDisplay ?? .fallback
    }
}

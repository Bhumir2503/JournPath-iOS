import MapKit
import SwiftUI

struct Coords: Codable, Hashable {
    var lat: Double
    var long: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: long)
    }
}

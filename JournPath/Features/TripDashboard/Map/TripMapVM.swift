import CoreLocation
import Foundation
import SwiftUI

import CoreLocation
import Foundation
import SwiftUI

struct TripMapAnnotation: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let iconName: String
    let color: Color
    let item: ItineraryItem

    static func == (lhs: TripMapAnnotation, rhs: TripMapAnnotation) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
final class TripMapVM {
    func annotations(for items: [ItineraryItem]) -> [TripMapAnnotation] {
        items.compactMap { item -> TripMapAnnotation? in
            guard let activity = item.activity,
                  let coords = activity.location.coords,
                  let id = item.id
            else { return nil }

            return TripMapAnnotation(
                id: id,
                coordinate: coords.coordinate,
                title: activity.title,
                iconName: "Activity",
                color: .blue,
                item: item
            )
        }
    }
}

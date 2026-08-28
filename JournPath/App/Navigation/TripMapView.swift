import CoreLocation
import Foundation
import MapKit
import SwiftUI

struct TripMapView: View {
    let tripId: String
    
    @State private var itineraryManager: ItineraryManager

    init(tripId: String) {
        self.tripId = tripId
        _itineraryManager = State(initialValue: ItineraryManager(tripId: tripId))
    }

    var body: some View {
        Map {
            UserAnnotation()
            
            ForEach(itineraryManager.items) { item in
                if let activity = item.activity {
                    Marker(
                        activity.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: activity.coords.lat,
                            longitude: activity.coords.long
                        )
                    )
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .navigationTitle("Trip Map")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            itineraryManager.startListening()
        }
    }
}

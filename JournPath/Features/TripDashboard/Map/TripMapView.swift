import CoreLocation
import Foundation
import MapKit
import SwiftUI

struct TripMapView: View {
    let tripId: String
    let tripName: String

    @State private var itineraryManager: ItineraryManager
    @StateObject private var locationManager = LocationManager()
    @State private var vm = TripMapVM()

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedItem: ItineraryItem?
    @State private var isCameraOnUser = false

    init(tripId: String, tripName: String) {
        self.tripId = tripId
        self.tripName = tripName
        _itineraryManager = State(initialValue: ItineraryManager(tripId: tripId))
    }

    private var isFollowingHeading: Bool {
        position == .userLocation(followsHeading: true, fallback: .automatic)
    }

    private var isTrackingUser: Bool {
        position == .userLocation(fallback: .automatic) || isCameraOnUser || isFollowingHeading
    }

    private var locationIconName: String {
        if isFollowingHeading {
            return "location.north.line.fill"
        } else if isTrackingUser {
            return "location.fill"
        } else {
            return "location"
        }
    }

    var body: some View {
        Map(position: $position) {
            // Add user location puck
            UserAnnotation()

            // Add itinerary annotations
            ForEach(vm.annotations(for: itineraryManager.items)) { annotation in
                Marker(annotation.title, systemImage: annotation.iconName, coordinate: annotation.coordinate)
                    .tint(annotation.color)
            }
        }
        .animation(.easeInOut, value: position)
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if isTrackingUser && !isFollowingHeading {
                        withAnimation {
                            position = .userLocation(followsHeading: true, fallback: .automatic)
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            position = .userLocation(fallback: .automatic)
                        }
                    }
                    locationManager.requestLocation()
                } label: {
                    Image(systemName: locationIconName)
                        .foregroundStyle(isTrackingUser ? Color.blue : Color.primary)
                }
            }
        }
        .navigationTitle(tripName)
        .onAppear {
            locationManager.requestLocation()
            itineraryManager.startListening()
        }
        .onReceive(locationManager.$locationStatus) { status in
            if let status = status {
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    locationManager.requestLocation()
                }
            }
        }
        .onMapCameraChange(frequency: .continuous) { context in
            if let userLoc = locationManager.lastLocation {
                let center = context.camera.centerCoordinate
                let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
                    .distance(from: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude))
                isCameraOnUser = distance < 100  // within 100 meters
            } else {
                isCameraOnUser = false
            }
        }
        //        .sheet(item: $selectedItem) { item in
        //            ItineraryItemDetailView(item: item)
        //        }
    }

}

// MARK: - Search Coordinator
import CoreLocation
import Foundation
import MapKit
import SwiftUI

enum ActivitySheet: Identifiable {
    case myCurrentLocation
    case activity(PlaceResult)
    case stay(PlaceResult)
    case transit(PlaceResult)
    case flight(PlaceResult)
    case custom

    var id: String {
        switch self {
        case .myCurrentLocation: return "myCurrentLocation"
        case .activity(let place): return "activity-\(place.id)"
        case .stay(let place): return "stay-\(place.id)"
        case .transit(let place): return "transit-\(place.id)"
        case .flight(let place): return "flight-\(place.id)"
        case .custom: return "custom"
        }
    }
}

enum LocationIndicatorStatus: Equatable {
    case requesting
    case permissionDenied
    case usingCurrent
    case custom(String)
}

@Observable
@MainActor
final class ItineraryBuilderVM: NSObject, CLLocationManagerDelegate {

    // MARK: - Search State

    var searchQuery = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            onQueryChange(searchQuery)
        }
    }

    var searchTokens: [POICategory] = [] {
        didSet {
            guard searchTokens != oldValue else { return }
            onTokenChange(searchTokens)
        }
    }

    var searchResults: [PlaceResult] = []
    var isSearching = false
    var hasCompletedSearch = false
    var showError = false

    var activeSheet: ActivitySheet? = nil

    // MARK: - Location State

    var searchNearLocation: SearchNearLocation? {
        didSet {
            saveCustomLocation()
            updateLocationIndicator()

            if !searchQuery.isEmpty {
                performTextSearch(query: searchQuery)
            } else if let category = searchTokens.first {
                performCategorySearch(category: category)
            }
        }
    }

    var locationIndicatorStatus: LocationIndicatorStatus = .requesting

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private var userLocation: CLLocationCoordinate2D?
    private var debounceTask: Task<Void, Never>? = nil
    private var isProgrammaticUpdate = false

    // MARK: - Init

    override init() {
        super.init()
        setupLocationManager()
        loadCustomLocation()
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            updateLocationIndicator()
        }
        locationManager.startUpdatingLocation()
    }

    // MARK: - Reactive Handlers

    private func onQueryChange(_ query: String) {
        guard !isProgrammaticUpdate else { return }

        debounceTask?.cancel()
        hasCompletedSearch = false
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            if query.isEmpty {
                if let category = self.searchTokens.first {
                    self.performCategorySearch(category: category)
                } else {
                    self.searchResults = []
                }
            } else {
                self.performTextSearch(query: query)
            }
        }
    }

    private func onTokenChange(_ tokens: [POICategory]) {
        guard !isProgrammaticUpdate else { return }
        hasCompletedSearch = false

        if tokens.isEmpty {
            if searchQuery.isEmpty {
                searchResults = []
            } else {
                performTextSearch(query: searchQuery)
            }
        } else if let category = tokens.first {
            performCategorySearch(category: category)
        }
    }

    // MARK: - Actions

    func handleCategoryTap(category: POICategory) {
        isProgrammaticUpdate = true
        self.searchTokens = [category]
        self.searchQuery = ""
        isProgrammaticUpdate = false
        hasCompletedSearch = false

        performCategorySearch(category: category)
    }

    func routeResolvedItem(_ resolved: PlaceResult) {
        let type = searchTokens.first?.type ?? .activity
        switch type {
        case .lodging:
            activeSheet = .stay(resolved)
        case .transit:
            activeSheet = .transit(resolved)
        case .flight:
            activeSheet = .flight(resolved)
        default:
            activeSheet = .activity(resolved)
        }
    }

    // MARK: - Search

    private func performTextSearch(query: String) {
        self.isSearching = true
        self.hasCompletedSearch = false
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest

        if let category = searchTokens.first, !category.poiFilters.isEmpty {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: category.poiFilters)
        }

        if let coordinate = searchNearLocation?.coordinate ?? userLocation {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
        }

        Task {
            do {
                let response = try await MKLocalSearch(request: request).start()
                self.searchResults = response.mapItems.map {
                    PlaceResult(
                        title: $0.name ?? "Unknown",
                        subtitle: $0.address?.fullAddress ?? "",
                        coordinate: $0.location.coordinate,
                        mapItem: $0
                    )
                }
            } catch {
                self.searchResults = []
            }
            self.isSearching = false
            self.hasCompletedSearch = true
        }
    }

    private func performCategorySearch(category: POICategory) {
        self.isSearching = true
        self.hasCompletedSearch = false
        let request = MKLocalSearch.Request()
        request.resultTypes = .pointOfInterest

        if let coordinate = searchNearLocation?.coordinate ?? userLocation {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
        }

        request.pointOfInterestFilter =
            category.poiFilters.isEmpty
            ? nil
            : MKPointOfInterestFilter(including: category.poiFilters)
        if category.poiFilters.isEmpty { request.naturalLanguageQuery = category.name }

        Task {
            do {
                let response = try await MKLocalSearch(request: request).start()
                self.searchResults = response.mapItems.map {
                    PlaceResult(
                        title: $0.name ?? "Unknown",
                        subtitle: $0.address?.fullAddress ?? "",
                        coordinate: $0.location.coordinate,
                        mapItem: $0
                    )
                }
            } catch {
                self.searchResults = []
            }
            self.isSearching = false
            self.hasCompletedSearch = true
        }
    }

    // MARK: - Helpers

    private func updateLocationIndicator() {
        if let location = searchNearLocation {
            locationIndicatorStatus = .custom(location.name)
        } else if locationManager.authorizationStatus == .denied
            || locationManager.authorizationStatus == .restricted
        {
            locationIndicatorStatus = .permissionDenied
        } else if locationManager.authorizationStatus == .notDetermined {
            locationIndicatorStatus = .requesting
        } else {
            locationIndicatorStatus = .usingCurrent
        }
    }

    private func loadCustomLocation() {
        if let data = UserDefaults.standard.data(forKey: "searchNearLocationData"),
            let location = try? JSONDecoder().decode(SearchNearLocation.self, from: data)
        {
            self.searchNearLocation = location
        }
    }

    private func saveCustomLocation() {
        if let location = searchNearLocation,
            let data = try? JSONEncoder().encode(location)
        {
            UserDefaults.standard.set(data, forKey: "searchNearLocationData")
        } else {
            UserDefaults.standard.removeObject(forKey: "searchNearLocationData")
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.updateLocationIndicator()
            if manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways
            {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.userLocation = location.coordinate
            manager.stopUpdatingLocation()
        }
    }
}

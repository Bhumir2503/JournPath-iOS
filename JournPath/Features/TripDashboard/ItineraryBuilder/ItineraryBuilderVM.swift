import CoreLocation
import Foundation
import MapKit
import SwiftUI

enum ActivitySheet: String, Identifiable {
    case myCurrentLocation
    var id: String { rawValue }
}

enum FormDestination: Hashable {
    case activity(PlaceResult)
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

    var activeSheet: ActivitySheet?
    var navigationPath: [FormDestination] = []

    // MARK: - Location State

    var searchNearLocation: SearchNearLocation? {
        didSet {
            saveCustomLocation()
            updateLocationIndicator()
            rerunActiveSearch()
        }
    }

    var locationIndicatorStatus: LocationIndicatorStatus = .requesting

    // MARK: - Private

    private let locationManager = CLLocationManager()
    private var userLocation: CLLocationCoordinate2D?
    private var debounceTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var isProgrammaticUpdate = false

    // MARK: - Init

    override init() {
        super.init()
        setupLocationManager()
        loadCustomLocation()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            updateLocationIndicator()
            locationManager.startUpdatingLocation()
        }
    }

    // MARK: - Reactive Handlers

    private func onQueryChange(_ query: String) {
        guard !isProgrammaticUpdate else { return }

        debounceTask?.cancel()
        hasCompletedSearch = false

        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }

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

        if let category = tokens.first {
            performCategorySearch(category: category)
        } else if searchQuery.isEmpty {
            searchResults = []
        } else {
            performTextSearch(query: searchQuery)
        }
    }

    private func rerunActiveSearch() {
        if !searchQuery.isEmpty {
            performTextSearch(query: searchQuery)
        } else if let category = searchTokens.first {
            performCategorySearch(category: category)
        }
    }

    // MARK: - Actions

    func handleCategoryTap(category: POICategory) {
        isProgrammaticUpdate = true
        searchTokens = [category]
        searchQuery = ""
        isProgrammaticUpdate = false

        hasCompletedSearch = false
        performCategorySearch(category: category)
    }

    /// Resolves the place's timezone, then navigates. Resolution happens
    /// before the form appears so its date pickers are pinned correctly.
    func routeResolvedItem(_ resolved: PlaceResult) {
        navigationPath.append(.activity(resolved))
    }

    // MARK: - Search

    private func performTextSearch(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest

        if let category = searchTokens.first, !category.poiFilters.isEmpty {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: category.poiFilters)
        }

        run(request)
    }

    private func performCategorySearch(category: POICategory) {
        let request = MKLocalSearch.Request()
        request.resultTypes = .pointOfInterest

        if category.poiFilters.isEmpty {
            request.naturalLanguageQuery = category.name
        } else {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: category.poiFilters)
        }

        run(request)
    }

    private func run(_ request: MKLocalSearch.Request) {
        if let coordinate = searchNearLocation?.coordinate ?? userLocation {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
        }

        searchTask?.cancel()
        isSearching = true
        hasCompletedSearch = false

        searchTask = Task { [weak self] in
            let results: [PlaceResult]
            do {
                let response = try await MKLocalSearch(request: request).start()
                results = response.mapItems.map { item in
                    PlaceResult(
                        title: item.name ?? "Unknown",
                        subtitle: item.address?.fullAddress ?? "",
                        coordinate: item.location.coordinate,
                        mapItem: item,
                        timeZone: item.timeZone
                    )
                }
            } catch {
                results = []
            }

            guard !Task.isCancelled, let self else { return }
            self.searchResults = results
            self.isSearching = false
            self.hasCompletedSearch = true
        }
    }

    // MARK: - Helpers

    private func updateLocationIndicator() {
        if let location = searchNearLocation {
            locationIndicatorStatus = .custom(location.name)
        } else {
            switch locationManager.authorizationStatus {
            case .denied, .restricted: locationIndicatorStatus = .permissionDenied
            case .notDetermined: locationIndicatorStatus = .requesting
            default: locationIndicatorStatus = .usingCurrent
            }
        }
    }

    private func loadCustomLocation() {
        guard let data = UserDefaults.standard.data(forKey: "searchNearLocationData"),
            let location = try? JSONDecoder().decode(SearchNearLocation.self, from: data)
        else { return }
        searchNearLocation = location
    }

    private func saveCustomLocation() {
        if let location = searchNearLocation, let data = try? JSONEncoder().encode(location) {
            UserDefaults.standard.set(data, forKey: "searchNearLocationData")
        } else {
            UserDefaults.standard.removeObject(forKey: "searchNearLocationData")
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.updateLocationIndicator()
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self?.locationManager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor [weak self] in
            self?.userLocation = coordinate
            self?.locationManager.stopUpdatingLocation()
        }
    }
}

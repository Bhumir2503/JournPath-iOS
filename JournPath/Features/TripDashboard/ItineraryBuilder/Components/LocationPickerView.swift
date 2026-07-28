import Combine
import Foundation
import MapKit
import SwiftUI
import UIKit

struct SearchNearLocation: Codable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var vm = LocationPickerVM()
    @State private var locationManager = LocationManager()
    var onSelect: (SearchNearLocation?) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if locationManager.hasPermission || locationManager.authorizationStatus == .notDetermined {                        Button {
                            onSelect(nil)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                Text("Current Location")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    } else {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "location.slash.fill")
                                    .foregroundColor(.gray)
                                Text("Enable Location in Settings")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if vm.searchQuery.isEmpty && !vm.recentLocations.isEmpty {
                    Section("Recent Locations") {
                        ForEach(vm.recentLocations, id: \.self) { location in
                            Button {
                                onSelect(location)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.secondary)
                                    Text(location.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                
                if !vm.searchResults.isEmpty {
                    Section("Results") {
                        ForEach(vm.searchResults, id: \.self) { completion in
                            Button {
                                Task {
                                    if let location = await vm.resolve(completion: completion) {
                                        vm.addRecentLocation(location)
                                        onSelect(location)
                                        dismiss()
                                    }
                                }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(completion.title)
                                        .foregroundColor(.primary)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $vm.searchQuery, prompt: "Search for a city...")
            .navigationTitle("Search Near")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

class LocationPickerVM: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var recentLocations: [SearchNearLocation] = []
    
    private var completer: MKLocalSearchCompleter
    private var cancellable: AnyCancellable?
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        
        completer.delegate = self
        completer.resultTypes = .address
        
        if let data = UserDefaults.standard.data(forKey: "recentSearchNearLocationsData"),
           let locations = try? JSONDecoder().decode([SearchNearLocation].self, from: data) {
            self.recentLocations = locations
        }
        
        // Use Combine to debounce search query
        cancellable = $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                if query.isEmpty {
                    self?.searchResults = []
                } else {
                    self?.completer.queryFragment = query
                }
            }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.searchResults = []
    }
    
    func addRecentLocation(_ location: SearchNearLocation) {
        var newLocations = recentLocations.filter { $0 != location } // remove duplicates
        newLocations.insert(location, at: 0)
        if newLocations.count > 5 {
            newLocations = Array(newLocations.prefix(5))
        }
        self.recentLocations = newLocations
        if let data = try? JSONEncoder().encode(newLocations) {
            UserDefaults.standard.set(data, forKey: "recentSearchNearLocationsData")
        }
    }
    
    func resolve(completion: MKLocalSearchCompletion) async -> SearchNearLocation? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            if let item = response.mapItems.first {
                let name = item.name ?? completion.title
                let coordinate = item.location.coordinate
                return SearchNearLocation(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
        } catch {
            print("Failed to resolve location: \(error)")
        }
        return nil
    }
}

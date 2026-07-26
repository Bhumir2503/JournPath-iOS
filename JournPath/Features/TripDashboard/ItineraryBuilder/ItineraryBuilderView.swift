import MapKit
import SwiftUI

struct ItineraryBuilderView: View {
    @State private var vm = ItineraryBuilderVM()
    @Environment(TripManager.self) private var trip
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $vm.navigationPath) {
            Group {
                if !vm.searchTokens.isEmpty || !vm.searchQuery.isEmpty {
                    if vm.isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if vm.hasCompletedSearch && vm.searchResults.isEmpty {
                        ContentUnavailableView.search(text: vm.searchQuery)
                    } else {
                        SearchListView(results: vm.searchResults) { place in
                            vm.routeResolvedItem(place)
                        }
                    }
                } else {
                    CategorySelectorView { category in
                        vm.handleCategoryTap(category: category)
                    }
                }
            }
            .navigationTitle("Add to Itinerary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                locationPickerHeader
            }
            .navigationDestination(for: FormDestination.self) { destination in
                switch destination {
                case .activity(let place):
                    ActivityFormView(trip: trip.currentTrip!, place: place) {
                        dismiss()
                    }
                case .lodging:
                    EmptyView()
                }
            }
            .searchable(
                text: $vm.searchQuery,
                tokens: $vm.searchTokens,
                prompt: "Search activities and places"
            ) { token in
                Label(token.name, systemImage: token.icon)
            }
            .sheet(isPresented: $vm.showLocationPicker) {
                LocationPickerView { location in
                    vm.searchNearLocation = location
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .presentationDragIndicator(.visible)
        }
    }
    // MARK: - Location Header

    private var locationPickerHeader: some View {
        Button {
            vm.showLocationPicker = true
        } label: {
            HStack(spacing: 6) {
                switch vm.locationIndicatorStatus {
                case .permissionDenied:
                    Image(systemName: "location.slash.fill")
                        .font(.system(size: 12))
                    Text("Set Search Location")
                case .requesting:
                    ProgressView().controlSize(.mini)
                    Text("Locating...")
                case .usingCurrent:
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                    Text("Searching near: Current Location")
                case .custom(let name):
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                    Text("Searching near: \(name)")
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(
                vm.locationIndicatorStatus == .permissionDenied ? .gray : .blue
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                vm.locationIndicatorStatus == .permissionDenied
                    ? Color.gray.opacity(0.1)
                    : Color.blue.opacity(0.1)
            )
            .clipShape(Capsule())
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

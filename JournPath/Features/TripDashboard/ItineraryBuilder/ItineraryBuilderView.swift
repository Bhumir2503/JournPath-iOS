import MapKit
import SwiftUI

struct ItineraryBuilderView: View {
    @State private var vm = ItineraryBuilderVM()
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
                        searchResultsList
                    }
                } else {
                    categoryList
                }
            }
            .navigationTitle("New Activity")
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
                    ActivityFormView(place: place) {
                        dismiss()
                    }
                }
            }
        }
        .searchable(
            text: $vm.searchQuery,
            tokens: $vm.searchTokens,
            prompt: "Search activities and places"
        ) { token in
            Label(token.name, systemImage: token.icon)
        }
        .sheet(item: $vm.activeSheet) { sheet in
            switch sheet {
            case .myCurrentLocation:
                LocationPickerView { location in
                    vm.searchNearLocation = location
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Location Header

    private var locationPickerHeader: some View {
        Button {
            vm.activeSheet = .myCurrentLocation
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

    // MARK: - Category List

    private var categoryList: some View {
        List {
            if let firstGroup = categoryGroups.first {
                Section {
                    HStack(spacing: 0) {
                        Spacer()
                        ForEach(firstGroup.items) { category in
                            CategoryIconBtn(category: category) {
                                vm.handleCategoryTap(category: category)
                            }
                            Spacer()
                        }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            ForEach(categoryGroups.dropFirst()) { group in
                Section {
                    ForEach(group.items) { category in
                        CategoryRowBtn(category: category) {
                            vm.handleCategoryTap(category: category)
                        }
                    }
                } header: {
                    Text(group.name)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        List {
            ForEach(vm.searchResults) { result in
                Button {
                    vm.routeResolvedItem(result)
                } label: {
                    SearchResultRow(result: result)
                }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: vm.searchResults.count)
    }
}



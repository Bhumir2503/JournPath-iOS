import MapKit
import SwiftUI

struct ItineraryBuilderView: View {
    @State private var vm = ItineraryBuilderVM()

    var body: some View {
        NavigationStack {
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
            .safeAreaInset(edge: .top) {
                locationPickerHeader
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
            case .activity(let place):
                ActivityFormView(place: place)
            case .stay(let place):
                LodgingFormView(place: place)
            case .transit:
                EmptyView()
            case .flight:
                EmptyView()
            case .custom:
                EmptyView()
            }
        }
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

// MARK: - Subviews

struct CategoryIconBtn: View {
    let category: POICategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(category.color)
                    .frame(width: 64, height: 64)
                    .background(category.color.opacity(0.15))
                    .clipShape(Circle())
                Text(category.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 74)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CategoryRowBtn: View {
    let category: POICategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(category.color)
                    .frame(width: 32, height: 32)
                    .background(category.color.opacity(0.15))
                    .clipShape(Circle())
                Text(category.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(UIColor.quaternaryLabel))
            }
        }
        .buttonStyle(.plain)
    }
}

struct SearchResultRow: View {
    let result: PlaceResult

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: result.activityDisplay.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(result.activityDisplay.color)
                .frame(width: 32, height: 32)
                .background(result.activityDisplay.color.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body)
                    .foregroundColor(.primary)
                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

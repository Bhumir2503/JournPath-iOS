import Kingfisher
import SwiftUI

struct TripListView: View {
    @AppStorage("lastTripId") var lastTripId: String?
    @State private var store = TripListStore()

    @Environment(AppRouter.self) private var router
    @Environment(SessionStore.self) private var session

    @State private var isShowingCreateTrip: Bool = false

    var body: some View {
        tripList
            .navigationTitle("My Trips")
            .searchable(text: Bindable(store).searchText, prompt: "Search for a trip")
            .toolbar { toolbar }
            .sheet(isPresented: $isShowingCreateTrip) { CreateTripView() }
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear {
                if let userId = session.uid, router.path.isEmpty {
                    store.startListening(userId: userId)
                }
            }
            .onDisappear {
                store.stopListening()
            }
            .onChange(of: router.path) { _, newPath in
                if newPath.isEmpty, let userId = session.uid {
                    lastTripId = nil
                    store.startListening(userId: userId)
                }
            }
    }

    @ViewBuilder
    private var tripList: some View {
        if store.hasFetchedTrips && store.trips.isEmpty {
            EmptyTripList()
        } else if !store.searchText.isEmpty && store.filteredTrips.isEmpty {
            ContentUnavailableView.search(text: store.searchText)
        } else {
            List {
                TripListSection(title: "Current Trips", trips: store.currentTrips)
                TripListSection(title: "Upcoming Trips", trips: store.upcomingTrips)
                TripListSection(title: "Past Trips", trips: store.pastTrips)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                router.push(.settings)
            } label: {
                KFImage(URL(string: session.photoURL ?? ""))
                    .placeholder {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .foregroundStyle(.gray.opacity(0.8))
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            }
        }.sharedBackgroundVisibility(.hidden)

        DefaultToolbarItem(kind: .search, placement: .bottomBar)

        ToolbarItem(placement: .bottomBar) {
            Button {
                isShowingCreateTrip = true
            } label: {
                Label("New Trip", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

extension TripListView {
    struct EmptyTripList: View {
        var body: some View {
            ContentUnavailableView {
                Label("Your World Awaits", systemImage: "figure.hiking")
            } description: {
                Text("Start planning your next journey and keep all your itineraries, friends, and memories in one place.")
            }
        }
    }
}

import Kingfisher
import SwiftUI

struct TripListView: View {
    @AppStorage("lastTripId") var lastTripId: String?
    @State private var manager = TripListManager()

    @Environment(AppRouter.self) private var router
    @Environment(SessionStore.self) private var session

    @State private var isShowingCreateTrip: Bool = false

    var body: some View {
        tripList
            .navigationTitle("My Trips")
            .searchable(text: Bindable(manager).searchText, prompt: "Search for a trip")
            .toolbar { toolbar }
            .sheet(isPresented: $isShowingCreateTrip) { CreateTripView() }
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear {
                if let userId = session.uid, router.path.isEmpty {
                    manager.startListening(userId: userId)
                }
            }
            .onDisappear {
                manager.stopListening()
            }
            .onChange(of: router.path) { _, newPath in
                if newPath.isEmpty, let userId = session.uid {
                    lastTripId = nil
                    manager.startListening(userId: userId)
                }
            }
    }

    @ViewBuilder
    private var tripList: some View {
        if manager.hasFetchedTrips && manager.trips.isEmpty {
            EmptyTripList()
        } else if !manager.searchText.isEmpty && manager.filteredTrips.isEmpty {
            ContentUnavailableView.search(text: manager.searchText)
        } else {
            List {
                TripListSection(title: "Current Trips", trips: manager.currentTrips)
                TripListSection(title: "Upcoming Trips", trips: manager.upcomingTrips)
                TripListSection(title: "Past Trips", trips: manager.pastTrips)
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

    struct TripListSection: View {
        let title: String
        let trips: [TripInfo]

        @Environment(AppRouter.self) private var router
        @State private var showingDeleteAlert: Bool = false
        @State private var tripToDelete: TripInfo?

        private let tripService = TripService()

        var body: some View {
            if !trips.isEmpty {
                Section(title) {
                    ForEach(trips) { trip in
                        if let id = trip.id {
                            Button {
                                router.navigateToTrip(tripId: id)
                            } label: {
                                TripListRow(trip: trip)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    tripToDelete = trip
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Leave", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
                .alert(
                    "Leave Trip?",
                    isPresented: $showingDeleteAlert,
                    presenting: tripToDelete
                ) { trip in
                    Button("Cancel", role: .cancel) {}
                    Button(
                        "Leave",
                        role: .destructive
                    ) {
                        leaveTrip(trip)
                    }
                } message: { trip in
                    Text("Are you sure you want to leave this trip? You will lose access to it.")
                }
            }
        }
    }

    struct EmptyTripList: View {
        var body: some View {
            ContentUnavailableView {
                Label("Your World Awaits", systemImage: "figure.hiking")
            } description: {
                Text("Start planning your next journey and keep all your itineraries, friends, and memories in one place.")
            }
        }
    }

    struct TripListRow: View {
        let trip: TripInfo

        var body: some View {
            Label {
                HStack(alignment: .center, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {

                        Text(trip.name).fontWeight(.bold)

                        HStack {
                            Text(trip.startDate.displayStringUTC)
                            if !trip.startDate.isSameUTCDay(as: trip.endDate) {
                                Image(systemName: "arrow.right")
                                Text(trip.endDate.displayStringUTC)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                    }

                    Spacer()

                    if trip.isPremium {
                        Image(systemName: "crown.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.yellow)
                            .font(.headline)
                            .padding(.horizontal, 4)
                    }

                    Image(systemName: "chevron.right")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } icon: {
                Image(systemName: trip.dynamicIcon)
                    .foregroundStyle(trip.dynamicIconColor)
            }
        }
    }
}

extension TripListView.TripListSection {
    private func leaveTrip(_ trip: TripInfo) {
        guard let id = trip.id else { return }
        Task {
            do {
                try await tripService.leaveTrip(tripId: id)
            } catch {
                AppLogger.managers.error("Failed to leave trip: \(error.localizedDescription)")
            }
        }
    }
}

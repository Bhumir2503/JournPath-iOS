import SwiftUI

struct TripDashboardContent: View {
    @Environment(TripStore.self) private var tripStore
    @Environment(ParticipantStore.self) private var participants
    @Environment(AppRouter.self) private var router

    // Local state
    @State private var activeSheet: DashboardSheet?
    @State private var activeAlert: DashboardAlert?
    @State private var scrollOffset: CGFloat = 0

    // Service calls
    private let tripService = TripService()

    var body: some View {
        mainContent
            .navigationTitle(tripStore.trip?.name ?? "")
            .navigationSubtitle(tripStore.dateRangeString)
            .navigationBarTitleDisplayMode(.inline)

    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch tripStore.state {
            case .loaded(let trip):
                scrollBody(trip: trip)
                    .sheet(item: $activeSheet) { sheet in
                        DashboardSheetView(sheet: sheet)
                    }
                    .dashboardAlert($activeAlert, onLeave: leaveTrip, onRename: rename)
                    .toolbar {
                        TripDashboardToolbar(activeSheet: $activeSheet, activeAlert: $activeAlert)
                    }
            case .failed(let error):
                ContentUnavailableView {
                    Label("Couldn't load trip", systemImage: "exclamationmark.triangle")
                } description: {
                    if participants.me?.status == .kicked {
                        Text("You've been kicked from this trip.")
                    } else {
                        Text(error.localizedDescription)
                    }
                } actions: {
                    Button("Go to trips") {
                        router.popToRoot()
                    }
                }
            case .idle, .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .toolbar {
                        TripDashboardToolbar(activeSheet: $activeSheet, activeAlert: $activeAlert)
                    }
            }
        }
    }

    @ViewBuilder
    private func scrollBody(trip: Trip) -> some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .top) {
                    TripDashboardHeader(trip: trip, geometry: geometry, scrollOffset: scrollOffset)
                        .offset(y: scrollOffset > 0 ? 0 : scrollOffset)

                    // Each card lives in its own slice — see note below.
                    // NextUpCard { activeSheet = .itineraryBuilder }
                    // BalanceSummaryCard { activeSheet = .expenses }
                    // RecentFilesStrip { activeSheet = .storage }
                    // MemberAvatarRow { activeSheet = .participant }
                }
                .padding(.bottom, 32)
            }
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }, action: { _, newValue in scrollOffset = newValue })
            .ignoresSafeArea(edges: [.top])
        }
        .ignoresSafeArea()
    }

    private func leaveTrip() {
        Task {
            do {
                try await tripService.leave(tripId: tripStore.tripId)
                router.popToRoot()
            } catch {
                activeAlert = .error(error.localizedDescription)
            }
        }
    }

    private func rename(_ newName: String) {
        Task {
            do {
                try await tripService.rename(tripId: tripStore.tripId, newName: newName)
            } catch { activeAlert = .error(error.localizedDescription) }
        }
    }
}

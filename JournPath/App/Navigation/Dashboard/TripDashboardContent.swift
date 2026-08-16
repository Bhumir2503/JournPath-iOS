import SwiftUI

struct TripDashboardContent: View {
    @Environment(TripStore.self) private var tripStore
    @Environment(StorageStore.self) private var storageStore
    @Environment(SessionStore.self) private var session
    @Environment(ParticipantStore.self) private var participants
    @Environment(AppRouter.self) private var router

    @State private var activeSheet: DashboardSheet?
    @State private var activeAlert: DashboardAlert?
    @State private var scrollOffset: CGFloat = 0

    private let tripService = TripService()

    private var wasKicked: Bool { participants.me?.status == .kicked }

    var body: some View {
        mainContent
            .navigationTitle(tripStore.trip?.name ?? "")
            .navigationSubtitle(tripStore.dateRangeString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                TripDashboardToolbar(activeSheet: $activeSheet, activeAlert: $activeAlert)
            }
            .sheet(item: $activeSheet) { sheet in
                DashboardSheetView(sheet: sheet)
            }
            .dashboardAlert($activeAlert, onLeave: leaveTrip, onRename: rename)

            // Purge the download cache when kicked — those bytes are re-downloadable,
            // so wiping them is free. FileUploadCache is deliberately left alone: it may
            // hold the only copy of a photo whose upload never finished.
            .onChange(of: participants.me?.status) { _, status in
                if status == .kicked { purgeCaches() }
            }
            .onChange(of: tripStore.tier){ oldTier, newTier in
                if (oldTier == .free && newTier == .premium ){
                    activeSheet = nil
                    activeAlert = .upgraded
                }
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch tripStore.state {
        case .loaded(let trip):
            scrollBody(trip: trip)

        case .failed(let error):
            ContentUnavailableView {
                Label(
                    wasKicked ? "No longer in this trip" : "Couldn't load trip",
                    systemImage: wasKicked ? "person.slash" : "exclamationmark.triangle"
                )
            } description: {
                Text(
                    wasKicked
                        ? "You've been removed from this trip."
                        : error.localizedDescription)
            } actions: {
                Group {
                    if wasKicked {
                        Button("Back to trips") { router.popToRoot() }
                    } else {
                        Button("Retry") { tripStore.retry() }
                    }
                }.tint(.brand)
            }

        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func scrollBody(trip: Trip) -> some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .top) {
                    TripDashboardHeader(trip: trip, geometry: geometry, scrollOffset: scrollOffset)
                        .offset(y: scrollOffset > 0 ? 0 : scrollOffset)

                    // Each card lives in its own slice.
                    // NextUpCard { activeSheet = .itineraryBuilder }
                    // BalanceSummaryCard { activeSheet = .expenses }
                    // RecentFilesStrip { activeSheet = .storage }
                    // MemberAvatarRow { activeSheet = .participant }
                }
                .padding(.bottom, 32)
            }
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y
            } action: { _, newValue in
                scrollOffset = newValue
            }
            .ignoresSafeArea(edges: .top)
        }
        .ignoresSafeArea()
    }

    // MARK: - Actions

    /// Purges caches when kicked out of a trip
    private func purgeCaches() {
        let ids = storageStore.liveFileIds(uid: session.uid)
        ids.forEach { FileUploadCache.discard(id: $0) }
        FileDownloadCache.purge(tripId: tripStore.tripId)
        activeSheet = nil
    }

    private func leaveTrip() {
        // Purge first so it happens even if the write fails.
        FileDownloadCache.purge(tripId: tripStore.tripId)
        Task {
            do {
                try await tripService.leave(tripId: tripStore.tripId)
                router.popToRoot()
            } catch {
                activeAlert = .error(AnyAppError(error).localizedDescription)
            }
        }
    }

    private func rename(_ newName: String) {
        Task {
            do {
                try await tripService.rename(tripId: tripStore.tripId, newName: newName)
            } catch {
                activeAlert = .error(AnyAppError(error).localizedDescription)
            }
        }
    }
}

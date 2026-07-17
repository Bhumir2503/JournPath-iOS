import Kingfisher
import SwiftUI
import UnifiedBlurHash
import UserNotifications

enum DashboardSheet: Identifiable {
    case participant, storage, itineraryBuilder, notes, datePicker, imagePicker
    var id: Int { hashValue }
}

enum DashboardAlert: Identifiable, Hashable {
    case rename, leave
    case error(String)
    case tripDeleted
    case removed
    var id: Int { hashValue }
}

struct TripDashboardView: View {
    let tripId: String

    // MARK: - MVS Components
    @State private var tripManager: TripManager
    private let tripService = TripService()
    private let userDBService = UserDatabaseService()
    @Environment(AppRouter.self) private var router

    // MARK: - Local UI State (Unified)
    @State private var activeSheet: DashboardSheet?
    @State private var activeAlert: DashboardAlert?
    @State private var newTripName = ""
    @State private var scrollOffset: CGFloat = 0
    @State private var isSearchActive = false
    @State private var searchText = ""

    // Guards so an ejection alert isn't re-triggered after we've handled it.
    @State private var hasHandledRemoval = false

    var shareURL: URL? {
        var components = URLComponents(string: "https://usemyjourney.com/join")
        components?.queryItems = [
            URLQueryItem(name: "tripId", value: tripId),
            URLQueryItem(name: "inviteToken", value: tripManager.inviteToken),
        ]
        return components?.url
    }

    init(tripId: String) {
        self.tripId = tripId
        _tripManager = State(initialValue: TripManager(tripId: tripId))
    }

    var body: some View {
        ZStack {
            if let trip = tripManager.currentTrip {
                mainContent(trip: trip)
                    .sheet(item: $activeSheet) { sheet in
                        resolveSheet(sheet)
                    }
            }
        }
        .toolbar {
            TripDashboardToolbar(
                trip: tripManager.currentTrip,
                activeSheet: $activeSheet,
                activeAlert: $activeAlert,
                isSearchActive: $isSearchActive,
                shareURL: shareURL
            )
        }
        .environment(tripManager)
        .navigationTitle(tripManager.currentTrip?.name ?? "Loading...")
        .navigationSubtitle(tripManager.dateRangeString)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .secondarySystemBackground))
        .alert(
            alertTitle(for: activeAlert),
            isPresented: Binding(
                get: { activeAlert != nil },
                set: { if !$0 { activeAlert = nil } }
            ),
            presenting: activeAlert
        ) { alert in
            switch alert {
            case .leave:
                Button("Cancel", role: .cancel) {}
                Button("Confirm", role: .destructive) { leaveTrip() }
            case .rename:
                TextField("Trip Name", text: $newTripName)
                Button("Cancel", role: .cancel) {}
                Button("Save") { renameTrip() }
            case .tripDeleted:
                Button("OK") { router.popToRoot() }
            case .removed:
                Button("OK") { router.popToRoot() }
            case .error(_):
                Button("OK", role: .cancel) {}
            }
        } message: { alert in
            switch alert {
            case .leave:
                Text("Are you sure you want to leave this trip?")
            case .error(let msg):
                Text(msg)
            case .tripDeleted:
                Text("This trip has been deleted and is no longer available.")
            case .removed:
                Text("You've been removed from this trip and no longer have access.")
            default:
                EmptyView()
            }
        }
        .onAppear {
            tripManager.startListening()
            requestNotificationPermission()
        }
        // Ejection: captain kicked you (or your participant doc vanished).
        .onChange(of: tripManager.wasRemoved) { _, removed in
            guard removed, !hasHandledRemoval else { return }
            hasHandledRemoval = true
            activeAlert = .removed
        }
        // Trip deleted out from under us: the trip doc no longer exists while
        // we're viewing it. (currentTrip goes nil after having been non-nil.)
        .onChange(of: tripManager.currentTrip == nil) { wasNil, isNil in
            // Only treat nil as "deleted" if we had previously loaded the trip.
            guard isNil, tripManager.hasLoadedOnce, !hasHandledRemoval else { return }
            hasHandledRemoval = true
            activeAlert = .tripDeleted
        }
    }

    // MARK: - Main UI Components
    @ViewBuilder
    private func mainContent(trip: Trip) -> some View {
        GeometryReader { g in
            ScrollView {
                ZStack(alignment: .top) {
                    tripHeader(trip: trip, geometry: g)
                        .offset(y: scrollOffset > 0 ? 0 : scrollOffset)

                    VStack(spacing: 0) {
                        Color.clear.frame(height: g.size.height * 0.6)
                    }
                }
            }
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }, action: { _, newValue in scrollOffset = newValue })
            .ignoresSafeArea(edges: [.top, .bottom])
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func tripHeader(trip: Trip, geometry: GeometryProxy) -> some View {
        KFImage(URL(string: trip.imageURL))
            .placeholder {
                if let blurImage = Image(blurHash: trip.imageBlurHash) {
                    blurImage.resizable().scaledToFill()
                }
            }
            .resizable()
            .scaledToFill()
            .frame(
                width: geometry.size.width,
                height: (geometry.size.height * 0.65)
                    + (scrollOffset < 0 ? abs(scrollOffset) : 0)
            )
            .offset(y: scrollOffset > 0 ? min(scrollOffset, geometry.size.height * 0.45) : 0)
            .clipped()
    }
}

// MARK: - Helpers
extension TripDashboardView {
    @ViewBuilder
    private func resolveSheet(_ sheet: DashboardSheet) -> some View {
        switch sheet {
        case .participant:
            ParticipantManagementView(tripId: tripId)
                .presentationDragIndicator(.visible)
        case .storage:
            EmptyView()
        case .itineraryBuilder:
            EmptyView()
        case .notes:
            EmptyView()
        case .datePicker:
            DatePickerView(
                initialStartDate: tripManager.currentTrip?.startDate.deviceLocalFromUTCMidnight,
                initialEndDate: tripManager.currentTrip?.endDate.deviceLocalFromUTCMidnight,
                onCancel: { activeSheet = nil },
                onSubmit: { startDate, endDate in
                    Task {
                        try? await tripService.updateDates(tripId: tripId, startDate: startDate, endDate: endDate)
                    }
                    activeSheet = nil
                }
            )
            .presentationDetents([.fraction(0.7)])
        case .imagePicker:
            UnsplashImagePicker(
                preSearchText: tripManager.currentTrip?.name ?? "",
                onCancel: { activeSheet = nil },
                onSubmit: { image in
                    Task {
                        try await tripService.updateBackground(tripId: tripId, imageBlurHash: image.blurHash, imageURL: image.urls.regular, imageColor: image.color, imageAuthor: image.user.name)
                    }
                    activeSheet = nil
                }
            )
        }
    }

    private func alertTitle(for alert: DashboardAlert?) -> String {
        switch alert {
        case .leave: return "Leave Trip?"
        case .rename: return "Rename Trip"
        case .tripDeleted: return "Trip Deleted"
        case .removed: return "Removed From Trip"
        case .error(_): return "Error"
        case .none: return ""
        }
    }
}

// MARK: - Actions (Direct Service Calls)
extension TripDashboardView {
    private func leaveTrip() {
        Task {
            try? await userDBService.leaveTrip(tripId: tripId)
            router.pop()
        }
    }

    private func renameTrip() {
        Task {
            try? await tripService.rename(tripId: tripId, newName: newTripName)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

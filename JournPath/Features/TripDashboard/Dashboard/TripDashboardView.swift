import Kingfisher
import SwiftUI
import UnifiedBlurHash
import UserNotifications

enum DashboardSheet: Identifiable {
    case participant, storage, itineraryBuilder, notes, datePicker, imagePicker
    var id: Int { hashValue }
}

struct TripDashboardView: View {
    let tripId: String

    // States
    @State private var tripManager: TripManager
    @State private var participantManager: ParticipantManager

    // Services
    private let tripService = TripService()

    // Envs
    @Environment(AppRouter.self) private var router

    // Local State
    @State private var activeSheet: DashboardSheet?
    @State private var activeAlert: DashboardAlert?
    @State private var newTripName = ""
    @State private var scrollOffset: CGFloat = 0

    // Guards so an ejection alert isn't re-triggered after we've handled it.
    @State private var hasHandledRemoval = false

    var shareURL: URL? {
        // 1. Build the path string with the tripId interpolated
        let path = "https://journpath.com/invite/trip/\(tripManager.tripId)"

        // 2. Use URLComponents to safely add the token query parameter
        var components = URLComponents(string: path)
        components?.queryItems = [
            URLQueryItem(name: "token", value: tripManager.inviteToken)
        ]

        return components?.url
    }

    init(tripId: String) {
        self.tripId = tripId
        _tripManager = State(initialValue: TripManager(tripId: tripId))
        _participantManager = State(initialValue: ParticipantManager(tripId: tripId))
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
                shareURL: shareURL
            )
        }
        .environment(tripManager)
        .environment(participantManager)
        .navigationTitle(tripManager.currentTrip?.name ?? "Loading...")
        .navigationSubtitle(tripManager.dateRangeString)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .secondarySystemBackground))
        .alert(
            activeAlert?.title ?? "",
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
                Button("Save") { renameTrip() }.disabled(newTripName.isEmpty || newTripName == tripManager.currentTrip?.name)
            case .tripDeleted:
                Button("OK") { router.popToRoot() }
            case .removed:
                Button("OK") { router.popToRoot() }
            case .upgraded:
                Button("OK") {}
            case .error(_):
                Button("OK", role: .cancel) {}
            }
        } message: { alert in
            if let message = alert.message {
                Text(message)
            }
        }
        .onAppear {
            tripManager.startListening()
            participantManager.startListening()
            requestNotificationPermission()
        }
        .onChange(of: tripManager.wasRemoved) { _, removed in
            guard removed, !hasHandledRemoval else { return }
            hasHandledRemoval = true
            activeAlert = .removed
        }
        .onChange(of: tripManager.currentTrip == nil) { wasNil, isNil in
            guard isNil, tripManager.hasLoadedOnce, !hasHandledRemoval else { return }
            hasHandledRemoval = true
            activeAlert = .tripDeleted
        }
        .onChange(of: tripManager.currentUserRole) { _, role in
            if role == .observer {
                if activeSheet == .itineraryBuilder {
                    activeSheet = .none
                }
            }
        }
        .onChange(of: tripManager.currentTrip?.tier) { prev, cur in
            if prev == .free && cur == .premium {
                activeAlert = .upgraded
            }
        }
    }

    // MARK: - Main UI Components
    @ViewBuilder
    private func mainContent(trip: Trip) -> some View {
        GeometryReader { g in
            ScrollView {
                ZStack(alignment: .top) {
                    TripDashboardHeader(
                        trip: trip,
                        geometry: g,
                        scrollOffset: scrollOffset
                    ).offset(y: scrollOffset > 0 ? 0 : scrollOffset)

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
            StorageHubView(tripId: tripId)
        case .itineraryBuilder:
            ItineraryBuilderView()
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

}

// MARK: - Actions (Direct Service Calls)
extension TripDashboardView {
    private func leaveTrip() {
        Task {
            try? await tripService.leaveTrip(tripId: tripId)
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

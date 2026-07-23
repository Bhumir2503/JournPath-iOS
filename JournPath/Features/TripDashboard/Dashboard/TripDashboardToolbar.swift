import SwiftUI

struct TripDashboardToolbar: ToolbarContent {
    let trip: Trip?
    @Environment(TripManager.self) private var tripManager

    // Bindings are "events" that the View handles
    @Binding var activeSheet: DashboardSheet?
    @Binding var activeAlert: DashboardAlert?
    let shareURL: URL?

    @Environment(AppRouter.self) private var router

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            //Share
            if let url = shareURL {
                ShareLink(item: url, preview: SharePreview("Join me on my trip on MyJourney")) {
                    Label("Invite Friends", systemImage: "square.and.arrow.up")
                }
            } else {
                Button {
                } label: {
                    Label("Invite Friends", systemImage: "square.and.arrow.up")
                }
                .disabled(true)
            }

            // Map Button
            Button {
                if let tripId = trip?.id {
                    router.navigateToTripMap(tripId: tripId)
                }
            } label: {
                Image(systemName: "map")
            }
            .disabled(trip == nil)

            // Command Menu
            TripDashboardMenu(
                trip: trip,
                activeSheet: $activeSheet,
                activeAlert: $activeAlert
            )
        }

        ToolbarItemGroup(placement: .bottomBar) {
            TripDashboardBottomBar(
                trip: trip,
                activeSheet: $activeSheet
            )
        }
    }
}

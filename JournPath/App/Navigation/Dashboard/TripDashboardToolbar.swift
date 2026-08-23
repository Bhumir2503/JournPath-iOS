import SwiftUI

struct TripDashboardToolbar: ToolbarContent {
    @Environment(TripStore.self) private var trip

    // Bindings are "events" that the View handles
    @Binding var activeSheet: DashboardSheet?
    @Binding var activeAlert: DashboardAlert?

    @Environment(AppRouter.self) private var router

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            //Share
            if let url = trip.shareURL {
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

            // Command Menu
            TripDashboardMenu(
                activeSheet: $activeSheet,
                activeAlert: $activeAlert
            )
        }

        ToolbarItemGroup(placement: .bottomBar) {
            TripDashboardBottomBar(
                activeSheet: $activeSheet
            )
        }
    }
}

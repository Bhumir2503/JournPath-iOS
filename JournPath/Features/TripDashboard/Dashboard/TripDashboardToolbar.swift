import SwiftUI

struct TripDashboardToolbar: ToolbarContent {
    let trip: Trip?
    @Environment(TripManager.self) private var tripManager

    // Bindings are "events" that the View handles
    @Binding var activeSheet: DashboardSheet?
    @Binding var activeAlert: DashboardAlert?
    @Binding var isSearchActive: Bool
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
            Menu {
                Button {
                    activeAlert = .rename
                } label: {
                    Label("Rename Trip", systemImage: "pencil")
                }
                Button {
                    activeSheet = .datePicker
                } label: {
                    Label("Update Dates", systemImage: "calendar")
                }
                Button {
                    activeSheet = .imagePicker
                } label: {
                    Label("Change Background", systemImage: "photo")
                }

                Divider()

                Button {
                    activeSheet = .participant
                } label: {
                    Label("Participants", systemImage: "person.3")
                }

                Divider()

                Button {
                    // Upgrade action
                } label: {
                    Label("Upgrade to Pro", systemImage: "sparkles")
                        .foregroundStyle(.blue)
                }

                Divider()

                Button(role: .destructive) {
                    activeAlert = .leave
                } label: {
                    Label("Leave Trip", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .disabled(trip == nil)
        }

        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                activeSheet = .storage
            } label: {
                Label("Storage", systemImage: "folder")
            }

            Button {
                activeSheet = .storage
            } label: {
                Label("Expenses", systemImage: "dollarsign.circle")
            }

            Button {
                activeSheet = .storage
            } label: {
                Label("Notes", systemImage: "list.bullet.clipboard")
            }

            Spacer()

            Button {
                activeSheet = .itineraryBuilder
            } label: {
                Label("Add Activity", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(trip == nil)
        }
    }
}

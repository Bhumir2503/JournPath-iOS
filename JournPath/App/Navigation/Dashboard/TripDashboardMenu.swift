import SwiftUI

struct TripDashboardMenu: View {
    @Environment(TripStore.self) private var trip
    @Environment(ParticipantStore.self) private var participant

    @Binding var activeSheet: DashboardSheet?
    @Binding var activeAlert: DashboardAlert?

    var body: some View {
        Menu {
            if participant.myRole != .observer {
                Button {
                    activeAlert = .rename
                } label: {
                    Label("Rename Trip", systemImage: "pencil")
                }
                if participant.myRole == .captain {
                    Button {
                        activeSheet = .datePicker
                    } label: {
                        Label("Update Dates", systemImage: "calendar")
                    }
                }
                Button {
                    activeSheet = .imagePicker
                } label: {
                    Label("Change Background", systemImage: "photo")
                }

                if participant.myRole == .captain {
                    Divider()
                }
            }

            Button {
                activeSheet = .participant
            } label: {
                Label("Participants", systemImage: "person.3")
            }

            if participant.myRole != .observer {
                Divider()
            }

            if trip.tier == .free {
                Button {
                    activeSheet = .paywall
                } label: {
                    Label("Upgrade to Pro", systemImage: "sparkles")
                        .foregroundStyle(.blue)
                }

                Divider()
            }

            Button(role: .destructive) {
                activeAlert = .leave
            } label: {
                Label("Leave Trip", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }
}

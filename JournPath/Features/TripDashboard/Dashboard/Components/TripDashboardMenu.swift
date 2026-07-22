import SwiftUI

struct TripDashboardMenu: View {
    let trip: Trip?

    @Environment(TripManager.self) private var tripManager

    @Binding var activeSheet: DashboardSheet?
    @Binding var activeAlert: DashboardAlert?

    var body: some View {
        Menu {
            if tripManager.currentUserRole != .observer {
                Button {
                    activeAlert = .rename
                } label: {
                    Label("Rename Trip", systemImage: "pencil")
                }
                if tripManager.currentUserRole == .captain {
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

                if tripManager.currentUserRole == .captain {
                    Divider()
                }
            }

            Button {
                activeSheet = .participant
            } label: {
                Label("Participants", systemImage: "person.3")
            }

            if tripManager.currentUserRole != .observer {
                Divider()
            }

            if tripManager.currentTrip?.tier == .free {
                Button {
                    // Upgrade action
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
        .disabled(trip == nil)
    }
}

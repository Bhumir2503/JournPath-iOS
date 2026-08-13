import SwiftUI

struct TripDashboardBottomBar: View {

    @Environment(ParticipantStore.self) private var participants
    @Binding var activeSheet: DashboardSheet?

    var body: some View {
        Group {
            Button {
                activeSheet = .storage
            } label: {
                Label("Storage", systemImage: "folder")
            }

            Button {
                activeSheet = .expenses
            } label: {
                Label("Expenses", systemImage: "dollarsign.circle")
            }

            Button {
                activeSheet = .checklist
            } label: {
                Label("Notes", systemImage: "list.bullet.clipboard")
            }

            Spacer()

            if participants.me?.role != .observer {
                Button {
                    activeSheet = .itineraryBuilder
                } label: {
                    Label("Add Activity", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.brand)
            }
        }
    }
}

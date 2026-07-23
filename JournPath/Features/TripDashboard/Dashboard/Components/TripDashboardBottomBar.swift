import SwiftUI

struct TripDashboardBottomBar: View {
    let trip: Trip?
    
    @Environment(TripManager.self) private var tripManager
    @Binding var activeSheet: DashboardSheet?

    var body: some View {
        Group {
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

            if tripManager.currentUserRole != .observer {
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
}

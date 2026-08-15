import SwiftUI

struct TripListSection: View {
    let title: String
    let trips: [Trip]
    @Environment(AppRouter.self) private var router

    var body: some View {
        if !trips.isEmpty {
            Section(title) {
                ForEach(trips) { trip in
                    if let id = trip.id {
                        Button {
                            router.navigateToTrip(tripId: id)
                        } label: {
                            TripListRow(trip: trip)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

import SwiftUI

struct TripDashboardView: View {
    let tripId: String

    @State private var session: TripSession?

    var body: some View {
        Group {
            if let session {
                TripDashboardContent()
                    .environment(session.trip)
                    .environment(session.participants)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .task(id: tripId) {
            guard session?.tripId != tripId else { return }  // survives push/pop
            let s = TripSession(tripId: tripId)
            s.start()
            session = s
        }
    }
}

import Kingfisher
import SwiftUI

struct TripListRow: View {
    let trip: Trip
    @State private var showLeaveAlert: Bool = false
    @State private var isLeaving: Bool = false
    @State private var leaveError: AnyAppError?
    @State private var showLeaveError: Bool = false

    var body: some View {
        Label {
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {

                    Text(trip.name).fontWeight(.bold)

                    Text(trip.dateRangeTextViaInterval)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                }

                Spacer()

                if isLeaving {
                    ProgressView()
                        .tint(.secondary)
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        } icon: {
            KFImage(trip.coverImage.smallURL)
                .placeholder { Image(systemName: "map").foregroundStyle(.blue) }
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        }
        .opacity(isLeaving ? 0.5 : 1.0)
        .disabled(isLeaving)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                showLeaveAlert = true
            } label: {
                Label("Leave", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .tint(.red)
        }
        .alert("Leave Trip", isPresented: $showLeaveAlert) {
            Button("Leave", role: .destructive) {
                leaveTrip(trip)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to leave \(trip.name)?")
        }
        .alert(error: $leaveError)
    }

    private func leaveTrip(_ trip: Trip) {
        guard let id = trip.id else { return }
        guard !isLeaving else { return }
        isLeaving = true

        Task {
            defer { isLeaving = false }
            do {
                let tripService = TripService()
                try await tripService.leave(tripId: id)
            } catch let error as LocalizedError {
                leaveError = AnyAppError(error)
            }
        }
    }

}

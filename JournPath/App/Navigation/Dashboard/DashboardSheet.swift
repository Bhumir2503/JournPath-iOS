import SwiftUI

enum DashboardSheet: String, Identifiable {
    case participant, storage, expenses, itineraryBuilder, notes, datePicker, imagePicker
    var id: String { rawValue }  // stable, no hashValue collisions
}

struct DashboardSheetView: View {
    let sheet: DashboardSheet

    @Environment(TripStore.self) private var tripStore
    @Environment(\.dismiss) private var dismiss
    private let tripService = TripService()

    var body: some View {
        switch sheet {
        case .participant: ParticipantsView()
        case .storage: StorageView()
        case .expenses: EmptyView()
        case .notes: EmptyView()
        case .itineraryBuilder: EmptyView()
        case .datePicker:
            DatePickerView(
                initialStartDate: tripStore.trip?.startDate.deviceLocalFromUTCMidnight,
                initialEndDate: tripStore.trip?.endDate.deviceLocalFromUTCMidnight,
                onCancel: { dismiss() },
                onSubmit: { startDate, endDate in
                    Task {
                        try? await tripService.updateDates(tripId: tripStore.tripId, startDate: startDate, endDate: endDate)
                    }
                    dismiss()
                }
            )
            .presentationDetents([.fraction(0.7)])
        case .imagePicker:
            UnsplashImagePicker(
                preSearchText: tripStore.name,
                onCancel: {
                    dismiss()
                },
                onSubmit: { image in
                    Task { try await tripService.updateCoverImage(tripId: tripStore.tripId, coverImage: CoverImage(image)) }
                    dismiss()
                }
            )
        }
    }
}

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
        case .participant: EmptyView()
        case .storage: EmptyView()
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
        case .imagePicker: EmptyView()
        }
    }
}

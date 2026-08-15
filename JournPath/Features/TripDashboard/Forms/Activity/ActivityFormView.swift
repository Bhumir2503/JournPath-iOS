import Kingfisher
import MapKit
import SwiftUI

struct ActivityFormView: View {

    private let trip: Trip
    private let onSaved: () -> Void

    @State var vm: ActivityFormVM

    init(trip: Trip, place: MKMapItem, onSaved: @escaping () -> Void = {}) {
        self.trip = trip
        _vm = State(initialValue: ActivityFormVM(place: place))
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TitleCard(title: $vm.activityTitle, placeholder: "Untitled Activity")
                ActivityFormDateCard(trip: trip, destinationTimeZone: vm.place.timeZone!, startDate: $vm.startDate, endDate: $vm.endDate, allDay: $vm.allDay)
                PlaceInfoCard(place: vm.place)
                NotesCard(note: $vm.note)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("New Activity")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
        .toolbar { toolbar }
    }

    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                vm.saveActivity(tripId: trip.id!)
                onSaved()
            } label: {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.borderedProminent)
        }
    }

}

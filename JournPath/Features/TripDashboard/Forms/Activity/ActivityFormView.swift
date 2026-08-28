import Kingfisher
import MapKit
import PhotosUI
import SwiftUI

struct ActivityFormView: View {

    private let trip: Trip
    private let onSaved: () -> Void

    @Environment(SessionStore.self) private var sessionStore
    @Environment(ParticipantStore.self) private var participantStore

    @State var vm: ActivityFormVM
    
    @State private var activeSource: FilePickerSource?
    @State private var photoItems: [PhotosPickerItem] = []

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
                
                if let expenseVM = vm.expenseVM {
                    InlineExpenseComponent(vm: expenseVM)
                }
                
                NotesCard(note: $vm.note)
                
                if !vm.pendingFiles.isEmpty {
                    PendingFilesGrid(files: vm.pendingFiles) { id in
                        vm.removePendingFile(id)
                    }
                }
                
                AttachmentsCard(activeSource: $activeSource)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .task {
            vm.setupExpenseVM(
                tripId: trip.id!,
                currentUid: sessionStore.uid ?? "",
                participantIds: participantStore.participants.compactMap { $0.id }
            )
            vm.isExpenseEnabled = true
        }
        .scrollIndicators(.hidden)
        .navigationTitle("New Activity")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
        .toolbar { toolbar }
        .modifier(
            FilePickers(
                activeSource: $activeSource,
                photoItems: $photoItems,
                onFiles: { vm.stage($0) },
                onPhotos: { await vm.stage(photos: $0) },
                onImage: { vm.stage(image: $0) },
                onScan: { vm.stage(scan: $0) },
                onError: { _ in }
            )
        )
    }

    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                Task {
                    _ = await vm.saveActivity(tripId: trip.id!)
                    onSaved()
                }
            } label: {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.borderedProminent)
        }
    }

}

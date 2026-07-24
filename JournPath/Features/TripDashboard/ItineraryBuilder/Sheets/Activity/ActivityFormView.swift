import Kingfisher
import MapKit
import SwiftUI

struct ActivityFormView: View {
    @Environment(TripManager.self) private var tripManager

    @State var vm: ActivityFormVM
    private let onSaved: () -> Void

    @State private var isSaving = false
    @State private var saveError: String?

    @State private var participantManager: ParticipantManager?

    init(place: PlaceResult, onSaved: @escaping () -> Void = {}) {
        _vm = State(initialValue: ActivityFormVM(place: place))
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                titleSection
                dateAndTimeSection
                PlaceInfoCard(infoItems: vm.infoItems)
                CostCard(participantManager: participantManager, info: $vm.costInfo)
                NotesCard(note: noteBinding)
                StorageCard()
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("New Activity")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
        }
        .onAppear {
            vm.computeSelectableRange(trip: tripManager.currentTrip)
            vm.setupDates(trip: tripManager.currentTrip)

            if participantManager == nil, let tripId = tripManager.currentTrip?.id {
                participantManager = ParticipantManager(tripId: tripId)
                participantManager?.startListening()
            }
        }
        .onChange(of: vm.costInfo.currencyCode) { _, newCode in
            if let tripId = tripManager.currentTrip?.id {
                UserDefaults.standard.set(newCode, forKey: "currencyCode_\(tripId)")
            }
        }
        .alert("Couldn't save", isPresented: showingSaveError) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .overlay(alignment: .bottom) {
            if vm.isAddressCopied {
                Text("Address Copied")
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
    }

    private var showingSaveError: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }

    var titleBinding: Binding<String> {
        Binding(
            get: { vm.item.activity?.title ?? "" },
            set: { vm.item.activity?.title = $0 }
        )
    }
    
    var noteBinding: Binding<String> {
        Binding(
            get: { vm.item.notes ?? "" },
            set: { vm.item.notes = $0 }
        )
    }



    private func save() async {
        guard let tripId = tripManager.currentTrip?.id else {
            saveError = "No active trip."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await vm.saveActivity(tripId: tripId)
            onSaved()
        } catch {
            saveError = error.localizedDescription
        }
    }

}

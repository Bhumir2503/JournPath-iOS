import Kingfisher
import MapKit
import SwiftUI

struct ActivityFormView: View {
    @Environment(TripManager.self) private var tripManager
    @Environment(\.dismiss) private var dismiss

    @State private var vm: ActivityFormVM

    @State private var showingDatePicker = false
    @State private var showingAmountSheet = false
    @State private var showingAttachmentsSheet = false
    @State private var showingNotesSheet = false
    @State private var isSaving = false
    
    @State private var participantManager: ParticipantManager?
    @State private var isSplitEnabled = false
    @State private var participantAmounts: [String: Double] = [:]
    @State private var selectedParticipantForAmount: Participant?

    init(place: PlaceResult) {
        _vm = State(initialValue: ActivityFormVM(place: place))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 24) {
                        dateAndTimeSection
                        informationSection
                        costSection
                        notesSection
                        storageSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                saveButton
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .onAppear {
                vm.setupDates(trip: tripManager.currentTrip)
                if participantManager == nil, let tripId = tripManager.currentTrip?.id {
                    participantManager = ParticipantManager(tripId: tripId)
                    participantManager?.startListening()
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerView(
                    initialStartDate: vm.startDate,
                    initialEndDate: vm.endDate,

                    onCancel: {
                        showingDatePicker = false
                    },
                    onSubmit: { start, end in
                        vm.updateDates(newStart: start, newEnd: end)
                        showingDatePicker = false
                    }
                )
                .presentationDetents([.fraction(0.7)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingAmountSheet) {
                Text("Amount Sheet")
            }
            .sheet(isPresented: $showingAttachmentsSheet) {
                Text("Attachments Sheet")
            }
            .sheet(isPresented: $showingNotesSheet) {
                Text("Notes Sheet")
            }
            .sheet(item: $selectedParticipantForAmount) { participant in
                Text("Enter amount for \(participant.displayName)")
                    .presentationDetents([.fraction(0.3), .medium])
            }
            .overlay(alignment: .bottom) {
                if vm.isAddressCopied {
                    Text("Address Copied")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .navigationTitle(vm.place.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Extracted Views

    @ViewBuilder
    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vm.place.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(vm.infoItems.enumerated()), id: \.offset) { index, item in
                    InfoRowView(icon: item.icon, text: item.text, isLink: item.isLink, showDivider: index < vm.infoItems.count - 1, action: item.action)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(28)
        }
    }

    @ViewBuilder
    private var dateAndTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                HStack {
                    Text("Dates")
                    Spacer()
                    Group {
                        if Calendar.current.isDate(vm.startDate, inSameDayAs: vm.endDate) {
                            Text(vm.startDate.displayString())
                        } else {
                            HStack(spacing: 8) {
                                Text(vm.startDate.displayString())
                                Image(systemName: "arrow.right")
                                Text(vm.endDate.displayString())
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(.capsule)
                    .onTapGesture {
                        showingDatePicker = true
                    }
                }
                .padding()

                Divider().padding(.leading, 16)
                Toggle("All Day", isOn: $vm.isAllDay.animation(.easeInOut))
                    .padding()

                if !vm.isAllDay {
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("Start Time")
                        Spacer()
                        DatePicker("", selection: $vm.startDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .fixedSize()
                            .onChange(of: vm.startDate) {
                                withAnimation {
                                    vm.validateEndDate()
                                }
                            }
                    }
                    .padding()

                    Divider().padding(.leading, 16)
                    HStack {
                        Text("End Time")
                        Spacer()
                        DatePicker("", selection: $vm.endDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .fixedSize()
                    }
                    .padding()
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(28)

            if !vm.isAllDay {
                HStack {
                    Image(systemName: "info.circle.fill")
                    Text("Times shown in \(vm.destinationTimeZone.identifier) timezone")
                }
                .padding(.horizontal, 12)
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .animation(.easeInOut, value: vm.isAllDay)
    }

    @ViewBuilder
    private var costSection: some View {
        let hasMultipleParticipants = (participantManager?.sortedParticipants.count ?? 0) > 1
        
        VStack(spacing: 0) {
            ActionRowView(icon: "dollarsign.circle.fill", title: "Amount", value: "10.00 USD", showDivider: hasMultipleParticipants) {
                showingAmountSheet = true
            }
            
            if hasMultipleParticipants {
                HStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                    
                    Toggle("Split Expense", isOn: $isSplitEnabled.animation())
                }
                .padding(.leading, 16)
                .padding(.trailing, 16)
                .padding(.vertical, 14)
                
                if isSplitEnabled {
                    Divider().padding(.leading, 16)
                    
                    VStack(alignment: .leading, spacing: 0) {
        
                        if let participantManager = participantManager {
                            VStack(spacing: 0) {
                                ForEach(Array(participantManager.sortedParticipants.enumerated()), id: \.element.id) { index, participant in
                                    let amount = participantAmounts[participant.id ?? ""] ?? 0.0
                                    
                                    Button {
                                        selectedParticipantForAmount = participant
                                    } label: {
                                        HStack(spacing: 12) {
                                            if let url = participant.photoURL, let imageURL = URL(string: url) {
                                                KFImage(imageURL)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 28, height: 28)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(systemName: "person.circle.fill")
                                                    .resizable()
                                                    .frame(width: 28, height: 28)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Text(participant.displayName)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            Text(String(format: "$%.2f", amount))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if index < participantManager.sortedParticipants.count - 1 {
                                        Divider().padding(.leading, 56)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(28)
    }

    @ViewBuilder
    private var storageSection: some View {
        Button {
            showingAttachmentsSheet = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)

                Text("Add Attachments")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("PDFs, Photos, Documents")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(28)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var notesSection: some View {
        Button {
            showingNotesSheet = true
        } label: {
            HStack(alignment: .top) {
                Image(systemName: "note.text")
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text(vm.note.isEmpty ? "Add a note..." : vm.note)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(28)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var saveButton: some View {
        Button {
            Task {
                guard let tripId = tripManager.currentTrip?.id else { return }
                isSaving = true
                do {
                    try await vm.saveActivity(tripId: tripId)
                    dismiss()
                } catch {
                    print("Failed to save activity: \(error.localizedDescription)")
                    isSaving = false
                }
            }
        } label: {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Save Activity")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSaving)
    }

    // MARK: - Reusable Detail Row
    struct InfoRowView: View {
        let icon: String
        let text: String
        let isLink: Bool
        let showDivider: Bool
        let action: (() -> Void)?

        var body: some View {
            Button {
                action?()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .foregroundColor(isLink ? .blue : (icon == "checkmark.circle.fill" ? .green : .secondary))
                        .frame(width: 24, height: 24)

                    VStack(spacing: 0) {
                        HStack {
                            Text(text)
                                .font(.subheadline)
                                .foregroundColor(isLink ? .blue : (icon == "checkmark.circle.fill" ? .green : .primary))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.vertical, 14)

                        if showDivider {
                            Divider()
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
            }
            .buttonStyle(.plain)
        }
    }
    struct ActionRowView: View {
        let icon: String
        let title: String
        let value: String?
        let showDivider: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)

                    VStack(spacing: 0) {
                        HStack {
                            Text(title)
                                .foregroundColor(.primary)
                            Spacer()
                            if let value = value {
                                Text(value)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 14)

                        if showDivider {
                            Divider()
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 16)
            }
            .buttonStyle(.plain)
        }
    }
}

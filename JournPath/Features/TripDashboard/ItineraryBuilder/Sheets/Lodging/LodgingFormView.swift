import MapKit
import SwiftUI

struct LodgingFormView: View {
    @Environment(TripManager.self) private var tripManager
    @Environment(\.dismiss) private var dismiss

    @State private var vm: LodgingFormVM

    @State private var showingDatePicker = false
    @State private var isSaving = false
    @FocusState private var isNoteFocused: Bool

    init(place: PlaceResult) {
        _vm = State(initialValue: LodgingFormVM(place: place))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    mapHeader

                    VStack(alignment: .leading, spacing: 24) {
                        titleHeader
                        informationSection
                        dateAndTimeSection
                        notesSection(proxy: proxy)
                        if isNoteFocused {
                            saveButton
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .onChange(of: isNoteFocused) { _, newValue in
                    if newValue {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo("notesSection", anchor: .center)
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    if isNoteFocused {
                        HStack {
                            Spacer()
                            Button(action: {
                                isNoteFocused = false
                            }) {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .font(.title2)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                    }
                    if !isNoteFocused {
                        saveButton
                            .padding(.horizontal)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .onAppear {
                vm.setupDates(trip: tripManager.currentTrip)
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerView(
                    initialStartDate: vm.checkinDate,
                    initialEndDate: vm.checkoutDate,
                    dateRange: vm.validDateRange(trip: tripManager.currentTrip),
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
        }
    }

    // MARK: - Extracted Views

    @ViewBuilder
    private var mapHeader: some View {
        if let coordinate = vm.place.coordinate {
            StaticMapSnapshotView(coordinate: coordinate, height: 350)
        }
    }

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
            Text("Information").font(.headline)
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
            HStack {
                Text("Stay Details").font(.headline)
                Spacer()
            }

            VStack(spacing: 0) {
                HStack {
                    Text("Dates")
                    Spacer()
                    Group {
                        if Calendar.current.isDate(vm.checkinDate, inSameDayAs: vm.checkoutDate) {
                            Text(vm.checkinDate.displayString())
                        } else {
                            HStack(spacing: 8) {
                                Text(vm.checkinDate.displayString())
                                Image(systemName: "arrow.right")
                                Text(vm.checkoutDate.displayString())
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
                HStack {
                    Text("Check-in Time")
                    Spacer()
                    DatePicker("", selection: $vm.checkinDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .fixedSize()
                        .onChange(of: vm.checkinDate) {
                            withAnimation {
                                vm.validateCheckoutDate()
                            }
                        }
                }
                .padding()

                Divider().padding(.leading, 16)
                HStack {
                    Text("Check-out Time")
                    Spacer()
                    DatePicker("", selection: $vm.checkoutDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .fixedSize()
                }
                .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(28)

            HStack {
                Image(systemName: "info.circle.fill")
                Text("Times shown in \(vm.destinationTimeZone.identifier) timezone")
            }
            .padding(.horizontal, 12)
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func notesSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes").font(.headline)
            VStack(spacing: 0) {
                TextField("Add a note (e.g. confirmation #, requests)", text: $vm.note, axis: .vertical)
                    .lineLimit(5...15)
                    .padding()
                    .focused($isNoteFocused)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(28)
        }
        .id("notesSection")
    }

    @ViewBuilder
    private var saveButton: some View {
        Button {
            Task {
                guard let tripId = tripManager.currentTrip?.id else { return }
                isSaving = true
                do {
                    try await vm.saveStay(tripId: tripId)
                    dismiss()
                } catch {
                    print("Failed to save stay: \(error.localizedDescription)")
                    isSaving = false
                }
            }
        } label: {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Save Stay")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .font(.headline)
        }
        .buttonStyle(.glassProminent)
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
}

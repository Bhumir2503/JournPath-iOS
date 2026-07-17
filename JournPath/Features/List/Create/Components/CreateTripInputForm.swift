import Foundation
import SwiftUI

extension CreateTripView {

    struct InputForm: View {
        @Environment(CreateTripViewModel.self) private var viewModel

        @FocusState private var isFocused: Bool
        @State private var showingImagePicker = false
        @State private var showingDatePicker = false

        var body: some View {
            @Bindable var bindableVM = viewModel

            VStack {
                TextField(
                    "", text: $bindableVM.name,
                    prompt: Text("Trip name")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.dynamicTextColor.opacity(0.6))
                )
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(viewModel.dynamicTextColor)
                .multilineTextAlignment(.center)
                .focused($isFocused)
                .padding(.bottom, 8)
                .onAppear { isFocused = true }
                .onSubmit { isFocused = true }
                .onChange(of: viewModel.name) { _, newValue in
                    if newValue.count > 25 { bindableVM.name = String(newValue.prefix(25)) }
                }

                // Extracted Components
                DateDisplayLabel()
                ActionButtons(
                    showingDatePicker: $showingDatePicker,
                    showingImagePicker: $showingImagePicker
                )
            }
            .sheet(isPresented: $showingImagePicker) { unsplashImagePicker }
            .sheet(isPresented: $showingDatePicker) { datePickerView }
        }

        // MARK: - Modals (Kept here as they require the local $state bindings)

        private var unsplashImagePicker: some View {
            UnsplashImagePicker(
                preSearchText: viewModel.name,
                onCancel: {
                    isFocused = true
                    showingImagePicker = false
                },
                onSubmit: { image in
                    viewModel.backgroundImageUrl = image.urls.regular
                    viewModel.backgroundColor = image.color
                    viewModel.backgroundBlurHash = image.blurHash
                    showingImagePicker = false
                    isFocused = true
                }
            )
        }

        private var datePickerView: some View {
            DatePickerView(
                initialStartDate: viewModel.startDate,
                initialEndDate: viewModel.endDate,
                onCancel: {
                    isFocused = true
                    showingDatePicker = false
                },
                onSubmit: { start, end in
                    viewModel.startDate = start
                    viewModel.endDate = end
                    showingDatePicker = false
                    isFocused = true
                }
            )
            .presentationDetents([.fraction(0.7)])
            .presentationDragIndicator(.visible)
        }
    }
}

extension CreateTripView {

    // MARK: - Date Display Label
    fileprivate struct DateDisplayLabel: View {
        @Environment(CreateTripViewModel.self) private var viewModel

        var body: some View {
            Group {
                if Calendar.current.isDate(viewModel.startDate, inSameDayAs: viewModel.endDate) {
                    Text(viewModel.startDate.displayString())
                } else {
                    HStack(spacing: 8) {
                        Text(viewModel.startDate.displayString())
                        Image(systemName: "arrow.right")
                        Text(viewModel.endDate.displayString())
                    }
                }
            }
            .foregroundColor(viewModel.dynamicTextColor.opacity(0.8))
            .fontWeight(.bold)
            .padding(.bottom)
        }
    }
    // MARK: - Action Buttons
    fileprivate struct ActionButtons: View {
        @Environment(CreateTripViewModel.self) private var viewModel

        @Binding var showingDatePicker: Bool
        @Binding var showingImagePicker: Bool

        var body: some View {
            HStack {
                Button {
                    showingDatePicker = true
                } label: {
                    VStack {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .padding(.bottom, 2)
                        Text( "Change Dates" )
                            .font(.headline.bold())
                    }
                }

                Divider()
                    .frame(width: 1, height: 60)
                    .overlay(viewModel.dynamicTextColor.opacity(0.6))
                    .padding(.horizontal, 40)

                Button {
                    showingImagePicker = true
                } label: {
                    VStack {
                        Image(systemName: "photo")
                            .font(.title3)
                            .padding(.bottom, 2)
                        Text("Background")
                            .font(.headline.bold())
                    }
                }
            }
            .foregroundColor(viewModel.dynamicTextColor.opacity(0.6))
        }
    }
}

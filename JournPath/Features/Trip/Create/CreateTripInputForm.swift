import Foundation
import SwiftUI

extension CreateTripView {

    struct InputForm: View {
        @Environment(CreateTripViewModel.self) private var viewModel

        @State private var isFocused: Bool = true
        @State private var showingDatePicker = false

        var body: some View {
            @Bindable var bindableVM = viewModel

            VStack {
                UIKitTextField(
                    text: $bindableVM.name,
                    isFocused: $isFocused,
                    placeholder: "Trip name",
                    textColor: viewModel.dynamicTextColor,
                    placeholderColor: viewModel.dynamicTextColor.opacity(0.6)
                )
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
                .onChange(of: viewModel.name) { _, newValue in
                    if newValue.count > 32 { bindableVM.name = String(newValue.prefix(32)) }
                }

                DateDisplayLabel()
                ActionButtons(showingDatePicker: $showingDatePicker)

                CoverAttribution()
            }
            .sheet(isPresented: $bindableVM.isShowingImagePicker) { unsplashImagePicker }
            .sheet(isPresented: $showingDatePicker) { datePickerView }
        }

        // MARK: - Modals

        private var unsplashImagePicker: some View {
            UnsplashImagePicker(
                preSearchText: viewModel.name,
                onCancel: {
                    viewModel.isShowingImagePicker = false
                    isFocused = true
                },
                onSubmit: { image in
                    viewModel.coverImage = CoverImage(image)
                    viewModel.isShowingImagePicker = false
                    isFocused = true
                }
            )
        }

        private var datePickerView: some View {
            DatePickerView(
                initialStartDate: viewModel.startDate?.toPickerDate(),
                initialEndDate: viewModel.endDate?.toPickerDate(),
                onCancel: {
                    isFocused = true
                    showingDatePicker = false
                },
                onSubmit: { start, end in
                    viewModel.startDate = start.toTripDate()
                    viewModel.endDate = end.toTripDate()
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

    // MARK: - Cover Attribution

    /// Unsplash requires the photographer credit to be visible wherever the
    /// photo is shown, with a link back to their profile.
    fileprivate struct CoverAttribution: View {
        @Environment(CreateTripViewModel.self) private var viewModel

        var body: some View {
            if let cover = viewModel.coverImage, let url = cover.profileURL {
                Link(destination: url) {
                    Text(cover.attributionText)
                        .font(.caption2)
                        .underline()
                }
                .foregroundStyle(viewModel.dynamicTextColor.opacity(0.7))
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Date Display Label

    fileprivate struct DateDisplayLabel: View {
        @Environment(CreateTripViewModel.self) private var viewModel

        var body: some View {
            Group {
                if let start = viewModel.startDate, let end = viewModel.endDate {
                    let startYear = Calendar.current.component(.year, from: start.toPickerDate())
                    let endYear = Calendar.current.component(.year, from: end.toPickerDate())

                    if Calendar.current.isDate(start.toPickerDate(), inSameDayAs: end.toPickerDate()) {
                        Text(
                            formatDate(
                                start.toPickerDate(),
                                includeYear: startYear != Calendar.current.component(.year, from: Date())))
                    } else {
                        HStack(spacing: 8) {
                            Text(formatDate(start.toPickerDate(), includeYear: startYear != endYear))
                            Image(systemName: "arrow.right")
                            Text(formatDate(end.toPickerDate(), includeYear: startYear != endYear))
                        }
                    }
                } else {
                    Text("Dates Not Set")
                }
            }
            .foregroundColor(viewModel.dynamicTextColor.opacity(0.8))
            .fontWeight(.bold)
            .padding(.bottom)
        }

        private func formatDate(_ date: Date, includeYear: Bool) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = includeYear ? "MMM d, yyyy" : "MMM d"
            return formatter.string(from: date)
        }
    }

    // MARK: - Action Buttons

    fileprivate struct ActionButtons: View {
        @Environment(CreateTripViewModel.self) private var viewModel

        @Binding var showingDatePicker: Bool

        var body: some View {
            HStack {
                Button {
                    showingDatePicker = true
                } label: {
                    VStack {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .padding(.bottom, 2)
                        Text("Change Dates")
                            .font(.headline.bold())
                    }
                }

                Divider()
                    .frame(width: 1, height: 60)
                    .overlay(viewModel.dynamicTextColor.opacity(0.6))
                    .padding(.horizontal, 40)

                Button {
                    viewModel.isShowingImagePicker = true
                } label: {
                    VStack {
                        Image(systemName: viewModel.coverImage == nil ? "photo.badge.plus" : "photo")
                            .font(.title3)
                            .padding(.bottom, 2)
                        Text(viewModel.coverImage == nil ? "Add Photo" : "Background")
                            .font(.headline.bold())
                    }
                }
            }
            .foregroundColor(viewModel.dynamicTextColor.opacity(0.6))
        }
    }
}

fileprivate struct UIKitTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String
    var textColor: Color
    var placeholderColor: Color
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.textAlignment = .center
        
        let font = UIFont.systemFont(ofSize: 28, weight: .bold)
        textField.font = font
        textField.tintColor = UIColor(textColor)
        
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        if isFocused {
            textField.becomeFirstResponder()
        }
        
        return textField
    }

        func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.textColor = UIColor(textColor)
        uiView.tintColor = UIColor(textColor)
        
        let font = UIFont.systemFont(ofSize: 28, weight: .bold)
        uiView.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor(placeholderColor),
                .font: font
            ]
        )
        
        DispatchQueue.main.async {
            if self.isFocused && !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            } else if !self.isFocused && uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: UIKitTextField

        init(_ parent: UIKitTextField) {
            self.parent = parent
        }

        @objc func textChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                if !self.parent.isFocused {
                    self.parent.isFocused = true
                }
            }
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                if self.parent.isFocused {
                    self.parent.isFocused = false
                }
            }
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.isFocused = true
            return true
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let currentText = textField.text ?? ""
            guard let stringRange = Range(range, in: currentText) else { return false }
            let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
            
            // Limit to 25 characters
            return updatedText.count <= 25
        }
    }
}

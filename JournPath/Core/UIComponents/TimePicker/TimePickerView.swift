import SwiftUI

struct TimePickerView: View {
    @StateObject private var vm: TimePickerVM
    var title: String
    var onCancel: () -> Void
    var onSubmit: (Date) -> Void

    init(
        title: String = "Select Time",
        initialTime: Date? = nil,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (Date) -> Void
    ) {
        self.title = title
        self._vm = StateObject(wrappedValue: TimePickerVM(initialTime: initialTime))
        self.onCancel = onCancel
        self.onSubmit = onSubmit
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "",
                    selection: $vm.selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .confirm) {
                        onSubmit(vm.selectedTime)
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }

            }
        }
    }
}

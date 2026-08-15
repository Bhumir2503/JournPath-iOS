import SwiftUI
import UIKit

struct ChecklistTextField: UIViewRepresentable {
    var placeholder: String
    @Binding var text: String
    var onEditingBegan: (() -> Void)? = nil
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        textField.returnKeyType = .done
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        
        // Listen for text changes to update the binding
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ChecklistTextField

        init(_ parent: ChecklistTextField) {
            self.parent = parent
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onEditingBegan?()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            // Trigger the submit action
            parent.onSubmit()
            // Return false to prevent the text field from resigning first responder (hiding keyboard)
            return false
        }
    }
}

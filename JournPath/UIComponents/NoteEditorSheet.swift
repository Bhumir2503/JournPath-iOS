import SwiftUI

struct NoteEditorSheet: View {
    @Binding var note: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    private let limit = 1000

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("Type notes here...")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
                
                CustomTextEditor(text: $draft, limit: limit)
            }
            .onChange(of: draft) { _, newValue in
                if newValue.count > limit {
                    draft = String(newValue.prefix(limit))
                }
            }
            .padding(.horizontal)
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        note = draft
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .onAppear {
                draft = note
            }
        }
        .presentationDragIndicator(.visible)
    }
}

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    var limit: Int = 1000

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear

        let accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 50))
        accessoryView.autoresizingMask = .flexibleWidth
        accessoryView.backgroundColor = .clear
        
        let countLabel = UILabel()
        countLabel.tag = 1001
        countLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        countLabel.textColor = .secondaryLabel
        
        accessoryView.addSubview(countLabel)
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            countLabel.trailingAnchor.constraint(equalTo: accessoryView.trailingAnchor, constant: -24),
            countLabel.bottomAnchor.constraint(equalTo: accessoryView.bottomAnchor, constant: -12)
        ])
        
        textView.inputAccessoryView = accessoryView

        textView.becomeFirstResponder()
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if let countLabel = uiView.inputAccessoryView?.viewWithTag(1001) as? UILabel {
            countLabel.text = "\(text.count)/\(limit)"
            countLabel.textColor = text.count >= limit ? .systemRed : .secondaryLabel
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor

        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            self.parent.text = textView.text
        }
    }
}

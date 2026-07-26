import SwiftUI

struct TitleCard: View {
    @Binding var title: String
    var placeholder: String = "Untitled"
    var isDisabled: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack {
            TextField(placeholder, text: $title)
                .font(.headline)
                .focused($isFocused)
                .submitLabel(.done)
                .lineLimit(1)
                .padding()
                .onChange(of: title) { _, newValue in
                    var processed = newValue.replacingOccurrences(of: "\n", with: " ")
                    if processed.count > 100 {
                        processed = String(processed.prefix(100))
                    }
                    if title != processed {
                        title = processed
                    }
                }
                .onSubmit {
                    isFocused = false
                }
                .disabled(isDisabled)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

import SwiftUI

struct FormCardButton<Content: View>: View {
    let action: () -> Void
    var backgroundColor: Color? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .padding()
                .frame(maxWidth: .infinity)
                .background(backgroundColor ?? Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct NotesCard: View {
    @Binding var note: String
    @State private var isEditing = false

    var body: some View {
        FormCardButton(action: {
            isEditing = true
        }, backgroundColor: note.isEmpty ? nil : Color.yellow.opacity(0.3)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "note.text")
                        .foregroundStyle(note.isEmpty ? .secondary : .primary)
                        .frame(width: 24, height: 24)

                    Text("Notes")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                Text(note.isEmpty ? "Add a note…" : note)
                    .font(.subheadline)
                    .foregroundStyle(note.isEmpty ? .secondary : .primary)
                    .lineLimit(10)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $isEditing) {
            NoteEditorSheet(note: $note)
        }
    }
}


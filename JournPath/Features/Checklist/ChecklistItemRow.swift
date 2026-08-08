import SwiftUI

struct ChecklistItemRow: View {
    let item: ChecklistItem
    let uid: String
    let tripId: String
    let listId: String
    let participantStore: ParticipantStore

    @State private var editTitle = ""
    @State private var editNote = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                ChecklistService().setChecked(
                    tripId: tripId,
                    listId: listId,
                    itemId: item.id!,
                    uid: uid,
                    checked: !item.isDone(for: uid)
                )
            } label: {
                Image(systemName: item.isDone(for: uid) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.isDone(for: uid) ? .blue : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Title", text: $editTitle)
                    .strikethrough(item.isDone(for: uid))
                    .foregroundColor(item.isDone(for: uid) ? .secondary : .primary)
                    .textFieldStyle(.plain)
                    .focused($isFocused)

                if !editNote.isEmpty || isFocused {
                    TextField("Add note...", text: $editNote)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                }
            }

            Spacer()
            if item.listKind == .shared, item.isCheckedByAnyone, let lastChecker = item.checkers.first, let participant = participantStore.participant(id: lastChecker.uid) {
                ParticipantAvatar(participant: participant, size: .small)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                ChecklistService().deleteItem(tripId: tripId, listId: listId, itemId: item.id!)
            } label: {
                Label("", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()

                ChecklistService().setChecked(
                    tripId: tripId,
                    listId: listId,
                    itemId: item.id!,
                    uid: uid,
                    checked: !item.isDone(for: uid)
                )
            } label: {
                Label("", systemImage: item.isDone(for: uid) ? "circle" : "checkmark")
            }
            .tint(item.isDone(for: uid) ? .gray : .blue)
        }
        .onAppear {
            editTitle = item.title
            editNote = item.note ?? ""
        }
        .onChange(of: editTitle) { oldValue, newValue in
            if newValue.count > 60 {
                editTitle = String(newValue.prefix(60))
            }
        }
        .onChange(of: editNote) { oldValue, newValue in
            if newValue.count > 150 {
                editNote = String(newValue.prefix(150))
            }
        }
        .onChange(of: item.title) { oldValue, newValue in
            if editTitle != newValue {
                editTitle = newValue
            }
        }
        .onChange(of: item.note) { oldValue, newValue in
            let newNote = newValue ?? ""
            if editNote != newNote {
                editNote = newNote
            }
        }
        .task(id: editTitle) {
            guard editTitle != item.title, !editTitle.isEmpty else { return }
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                ChecklistService().updateItem(
                    tripId: tripId,
                    listId: listId,
                    itemId: item.id!,
                    currentVersion: item.version,
                    title: editTitle,
                    note: editNote.isEmpty ? nil : editNote
                )
            } catch {
                // Cancelled
            }
        }
        .task(id: editNote) {
            guard editNote != (item.note ?? "") else { return }
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                ChecklistService().updateItem(
                    tripId: tripId,
                    listId: listId,
                    itemId: item.id!,
                    currentVersion: item.version,
                    title: editTitle,
                    note: editNote.isEmpty ? nil : editNote
                )
            } catch {
                // Cancelled
            }
        }
    }
}

import SwiftUI

struct ManageListsSheet: View {
    @Environment(TripStore.self) private var tripStore
    @Binding var isPresented: Bool
    let store: ChecklistStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.lists) { list in
                    HStack {
                        Image(systemName: list.icon ?? "star.fill")
                            .foregroundColor(.blue)
                        Text(list.title)
                        Spacer()
                        if list.kind == .shared {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onMove { source, destination in
                    var lists = store.lists
                    lists.move(fromOffsets: source, toOffset: destination)

                    guard let oldIndex = source.first else { return }
                    let movedListId = store.lists[oldIndex].id!
                    guard let newIndex = lists.firstIndex(where: { $0.id == movedListId }) else { return }

                    let prev = newIndex > 0 ? lists[newIndex - 1].sortIndex : nil
                    let next = newIndex < lists.count - 1 ? lists[newIndex + 1].sortIndex : nil

                    let newPosition = ChecklistPosition.between(prev, next)

                    ChecklistService().moveList(
                        tripId: tripStore.tripId,
                        listId: movedListId,
                        sortIndex: newPosition,
                        currentVersion: store.lists[oldIndex].version
                    )
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let list = store.lists[index]
                        if let listId = list.id {
                            ChecklistService().deleteList(tripId: tripStore.tripId, listId: listId)
                        }
                    }
                }
            }
            .navigationTitle("Manage Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
    }
}

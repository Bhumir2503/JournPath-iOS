import SwiftUI

struct ChecklistSheet: View {

    @Environment(TripStore.self) private var tripStore
    @Environment(SessionStore.self) private var sessionStore
    @Environment(ParticipantStore.self) private var participantStore

    @State private var store: ChecklistStore?
    @State private var isPresentingNewList = false
    @State private var editingList: Checklist?
    @State private var isPresentingManageLists = false
    @State private var listToDelete: Checklist?
    @State private var newItemTitle = ""
    @State private var scrollToBottomTrigger: UUID = UUID()

    var body: some View {
        NavigationStack {
            Group {
                if let store = store {
                    if !store.isLoaded {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if store.lists.isEmpty {
                        ContentUnavailableView {
                            Label("No Checklists", systemImage: "checklist")
                        } description: {
                            Text("Create a checklist to start packing.")
                        } actions: {
                            Button("Create Checklist") {
                                editingList = nil
                                isPresentingNewList = true
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Group {
                            if !store.isItemsLoaded {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if store.items.isEmpty {
                                ContentUnavailableView(
                                    "Empty List",
                                    systemImage: "list.clipboard",
                                    description: Text("Add your first item using the field below.")
                                )
                            } else {
                                ScrollViewReader { proxy in
                                    List {
                                        ForEach(store.items) { item in
                                            ChecklistItemRow(
                                                item: item,
                                                uid: sessionStore.uid ?? "",
                                                tripId: tripStore.tripId,
                                                listId: store.selectedListId ?? "",
                                                participantStore: participantStore
                                            )
                                            .listRowBackground(Color.clear)
                                        }
                                        .onDelete { indexSet in
                                            guard let listId = store.selectedListId else { return }
                                            for index in indexSet {
                                                let item = store.items[index]
                                                if let itemId = item.id {
                                                    ChecklistService().deleteItem(tripId: tripStore.tripId, listId: listId, itemId: itemId)
                                                }
                                            }
                                        }
                                        .onMove { source, destination in
                                            guard let listId = store.selectedListId else { return }
                                            var items = store.items
                                            items.move(fromOffsets: source, toOffset: destination)

                                            guard let oldIndex = source.first else { return }
                                            let movedItemId = store.items[oldIndex].id!
                                            guard let newIndex = items.firstIndex(where: { $0.id == movedItemId }) else { return }

                                            let prev = newIndex > 0 ? items[newIndex - 1].position : nil
                                            let next = newIndex < items.count - 1 ? items[newIndex + 1].position : nil

                                            let newPosition = ChecklistPosition.between(prev, next)

                                            ChecklistService().moveItem(
                                                tripId: tripStore.tripId,
                                                listId: listId,
                                                itemId: movedItemId,
                                                position: newPosition
                                            )

                                            if ChecklistPosition.needsRenormalization(prev, next) {
                                                ChecklistService().renormalizePositions(
                                                    tripId: tripStore.tripId,
                                                    listId: listId,
                                                    orderedItemIds: items.compactMap(\.id)
                                                )
                                            }
                                        }

                                        Color.clear.frame(height: 1).id("BOTTOM_MARKER")
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                    }
                                    .listStyle(.plain)
                                    .scrollContentBackground(.hidden)
                                    .scrollDismissesKeyboard(.interactively)
                                    .scrollIndicators(.hidden)
                                    .simultaneousGesture(
                                        DragGesture().onChanged { _ in
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        }
                                    )
                                    .onChange(of: scrollToBottomTrigger) {
                                        withAnimation {
                                            proxy.scrollTo("BOTTOM_MARKER", anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .top) {
                if let store = store, !store.lists.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(store.lists) { list in
                                let isSelected = (list.id == store.selectedListId)
                                Button {
                                    store.selectedListId = list.id
                                } label: {
                                    Label(list.title, systemImage: list.icon ?? "star.fill")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? .blue : Color(.systemGray5))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .contextMenu {
                                    Button {
                                        editingList = list
                                        isPresentingNewList = true
                                    } label: {
                                        Label("Edit List", systemImage: "pencil")
                                    }

                                    Button {
                                        isPresentingManageLists = true
                                    } label: {
                                        Label("Manage Lists", systemImage: "list.bullet")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        listToDelete = list
                                    } label: {
                                        Label("Delete List", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle("Checklists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingList = nil
                        isPresentingNewList = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                if let store = store, !store.lists.isEmpty {
                    ToolbarItemGroup(placement: .bottomBar) {
                        HStack(spacing: 12) {
                            Image(systemName: "circle")
                                .font(.title2)
                                .foregroundColor(.gray)

                            ChecklistTextField(
                                placeholder: "Add new item...",
                                text: $newItemTitle,
                                onEditingBegan: {
                                    scrollToBottomTrigger = UUID()
                                }
                            ) {
                                submitNewItem()
                                // Wait for the item to be inserted before scrolling
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                    scrollToBottomTrigger = UUID()
                                }
                            }
                            .frame(height: 36)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewList) {
                if let store = store {
                    NewChecklistSheet(isPresented: $isPresentingNewList, lists: store.lists, editingList: editingList)
                }
            }
            .sheet(isPresented: $isPresentingManageLists) {
                if let store = store {
                    ManageListsSheet(isPresented: $isPresentingManageLists, store: store)
                }
            }
            .confirmationDialog(
                "Delete List?",
                isPresented: Binding(
                    get: { listToDelete != nil },
                    set: { if !$0 { listToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let list = listToDelete, let listId = list.id {
                        ChecklistService().deleteList(tripId: tripStore.tripId, listId: listId)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let title = listToDelete?.title {
                    Text("Are you sure you want to delete '\(title)'?")
                }
            }
        }
        .task {
            if let uid = sessionStore.uid {
                store = ChecklistStore(tripId: tripStore.tripId, uid: uid)
                store?.start()
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func submitNewItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            let store = store,
            let listId = store.selectedListId,
            let uid = sessionStore.uid,
            let list = store.lists.first(where: { $0.id == listId })
        else { return }

        let position = (store.items.map(\.position).max() ?? 0) + ChecklistPosition.spacing
        ChecklistService().addItem(
            tripId: tripStore.tripId,
            listId: listId,
            title: trimmed,
            listKind: list.kind,
            position: position,
            uid: uid
        )
        newItemTitle = ""
    }

}

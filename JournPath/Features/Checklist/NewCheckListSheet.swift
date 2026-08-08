import SwiftUI

struct NewChecklistSheet: View {
    @Environment(TripStore.self) private var tripStore
    @Environment(SessionStore.self) private var sessionStore
    @Binding var isPresented: Bool
    let lists: [Checklist]
    var editingList: Checklist?

    @State private var title = ""
    @State private var kind: ChecklistKind = .shared
    @State private var icon: String = "star.fill"
    @FocusState private var titleFocused: Bool

    let icons = [
        "star.fill", "heart.fill", "house.fill", "gearshape.fill",
        "person.fill", "person.2.fill", "map.fill", "pin.fill",
        "car.fill", "airplane", "bed.double.fill", "fork.knife",
        "backpack.fill", "camera.fill", "ticket.fill", "creditcard.fill",
        "bell.fill", "envelope.fill",
    ]

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    nameRow
                    typeSection
                    iconSection
                }
                .padding(20)
            }
            .navigationTitle(editingList == nil ? "New list" : "Edit list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingList == nil ? "Create" : "Save") { submit() }
                        .fontWeight(.medium)
                        .disabled(trimmedTitle.isEmpty)
                }
            }

            .onAppear {
                if let list = editingList {
                    title = list.title
                    kind = list.kind
                    icon = list.icon ?? "star.fill"
                } else {
                    titleFocused = true
                }
            }
        }
    }

    // MARK: Sections

    private var nameRow: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Packing, documents…", text: $title)
                    .font(.body)
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit { if !trimmedTitle.isEmpty { submit() } }
                Divider()
            }
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Type")
            HStack(spacing: 10) {
                KindCard(
                    icon: "person.2.fill",
                    title: "Shared",
                    subtitle: "Everyone sees it",
                    isSelected: kind == .shared
                )
                .onTapGesture { kind = .shared }

                KindCard(
                    icon: "person.fill",
                    title: "Personal",
                    subtitle: "Only visible to you",
                    isSelected: kind == .personal
                )
                .onTapGesture { kind = .personal }
            }
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Icon")
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 6),
                spacing: 8
            ) {
                ForEach(icons, id: \.self) { sfIcon in
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            icon == sfIcon
                                ? Color.accentColor.opacity(0.12)
                                : Color(.secondarySystemBackground)
                        )
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: sfIcon)
                                .font(.title3)
                                .foregroundStyle(
                                    icon == sfIcon
                                        ? Color.accentColor
                                        : .secondary)
                        }
                        .onTapGesture { icon = sfIcon }
                        .accessibilityLabel(sfIcon)
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .kerning(0.5)
    }

    // MARK: Submit

    private func submit() {
        guard !trimmedTitle.isEmpty, let uid = sessionStore.uid else { return }

        if let listToEdit = editingList {
            ChecklistService().updateList(
                tripId: tripStore.tripId,
                listId: listToEdit.id!,
                title: trimmedTitle,
                kind: kind,
                icon: icon,
                currentVersion: listToEdit.version
            )
        } else {
            let position = (lists.map(\.sortIndex).max() ?? 0) + ChecklistPosition.spacing
            ChecklistService().createList(
                tripId: tripStore.tripId,
                title: trimmedTitle,
                kind: kind,
                icon: icon,
                sortIndex: position,
                uid: uid
            )
        }
        isPresented = false
    }

}
private struct KindCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            Text(title)
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(
                    isSelected
                        ? Color.accentColor.opacity(0.7)
                        : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            isSelected
                ? Color.accentColor.opacity(0.08)
                : Color(.secondarySystemBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32)
                .stroke(
                    isSelected ? Color.accentColor : Color(.separator),
                    lineWidth: isSelected ? 1.5 : 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}

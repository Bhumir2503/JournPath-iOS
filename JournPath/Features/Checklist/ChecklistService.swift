import FirebaseFirestore
import Foundation

// MARK: - Service

/// Write layer for the checklist slice. Reads live in the stores, which own
/// their own listeners.
///
/// Writes go out as dictionaries, deliberately — `checkedBy.<uid>` dotted paths
/// and `FieldValue.delete()` cannot be expressed through Codable encoding, and
/// encoding the whole struct on every edit would clobber concurrent
/// field-level changes.
///
/// No write here is awaited. Firestore queues locally and the listener reflects
/// the change immediately; awaiting the commit would block the UI on the
/// network for no benefit and hang outright when offline.
final class ChecklistService {

    private let db: Firestore

    init(db: Firestore = .firestore()) {
        self.db = db
    }

    // MARK: Paths

    private func checklists(_ tripId: String) -> CollectionReference {
        db.collection("trips").document(tripId).collection("checklists")
    }

    private func checklist(_ tripId: String, _ listId: String) -> DocumentReference {
        checklists(tripId).document(listId)
    }

    private func items(_ tripId: String, _ listId: String) -> CollectionReference {
        checklist(tripId, listId).collection("items")
    }

    private func item(
        _ tripId: String, _ listId: String, _ itemId: String
    ) -> DocumentReference {
        items(tripId, listId).document(itemId)
    }

    // MARK: List writes

    @discardableResult
    func createList(
        tripId: String,
        title: String,
        kind: ChecklistKind,
        icon: String?,
        sortIndex: Double,
        uid: String
    ) -> String {
        let ref = checklists(tripId).document()

        let data: [String: Any] = [
            "title": title,
            "kind": kind.rawValue,
            "icon": icon as Any? ?? NSNull(),
            "sortIndex": sortIndex,
            "createdBy": uid,
            "createdAt": FieldValue.serverTimestamp(),
            "clientCreatedAt": Timestamp(date: Date()),
            "updatedAt": FieldValue.serverTimestamp(),
            "version": 1,
        ]
        ref.setData(data)

        return ref.documentID
    }

    func updateList(
        tripId: String, listId: String, title: String, kind: ChecklistKind, icon: String?, currentVersion: Int
    ) {
        checklist(tripId, listId).updateData([
            "title": title,
            "kind": kind.rawValue,
            "icon": icon as Any? ?? NSNull(),
            "updatedAt": FieldValue.serverTimestamp(),
            "version": currentVersion + 1,
        ])
    }

    func moveList(
        tripId: String, listId: String, sortIndex: Double, currentVersion: Int
    ) {
        checklist(tripId, listId).updateData([
            "sortIndex": sortIndex,
            "updatedAt": FieldValue.serverTimestamp(),
            "version": currentVersion + 1,
        ])
    }

    /// Hard delete. Cloud Function handles recursive item cleanup via
    /// `onDocumentDeleted` + `recursiveDelete()` on the items subcollection.
    func deleteList(tripId: String, listId: String) {
        checklist(tripId, listId).delete()
    }

    // MARK: Item writes

    @discardableResult
    func addItem(
        tripId: String,
        listId: String,
        title: String,
        listKind: ChecklistKind,
        position: Double,
        uid: String,
        note: String? = nil,
        quantity: Int? = nil,
        assignedTo: String? = nil,
        completed: Bool = false
    ) -> String {
        let ref = items(tripId, listId).document()

        ref.setData([
            "title": title,
            "note": note ?? NSNull(),
            "quantity": quantity ?? NSNull(),
            "assignedTo": assignedTo ?? NSNull(),
            "position": position,
            "listKind": listKind.rawValue,
            "checkedBy": completed ? [uid: FieldValue.serverTimestamp()] : [:],
            "createdBy": uid,
            "createdAt": FieldValue.serverTimestamp(),
            "clientCreatedAt": Timestamp(date: Date()),
            "updatedAt": FieldValue.serverTimestamp(),
            "version": 1,
        ])

        return ref.documentID
    }

    /// The hot path — every checkbox tap.
    ///
    /// `updateData` with a dotted key is what makes this conflict-free. Do NOT
    /// swap it for `setData(merge: true)` with a nested dictionary: merge
    /// replaces the entire `checkedBy` map, and you lose the property that two
    /// people can check different items offline without one erasing the other.
    ///
    /// Version is deliberately not bumped. Checking isn't a content edit, and
    /// bumping would make every tap conflict with concurrent title edits.
    func setChecked(
        tripId: String, listId: String, itemId: String, uid: String, checked: Bool
    ) {
        item(tripId, listId, itemId).updateData([
            "checkedBy.\(uid)": checked
                ? FieldValue.serverTimestamp()
                : FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    /// Content edit. Only sends the fields that actually changed, so a rename
    /// on one device doesn't overwrite a quantity change on another.
    func updateItem(
        tripId: String,
        listId: String,
        itemId: String,
        currentVersion: Int,
        title: String? = nil,
        note: String?? = nil,
        quantity: Int?? = nil,
        assignedTo: String?? = nil
    ) {
        var fields: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp(),
            "version": currentVersion + 1,
        ]

        // Double optionals: .some(nil) means "clear this field",
        // nil means "leave it alone".
        if let title { fields["title"] = title }
        if let note { fields["note"] = note ?? NSNull() }
        if let quantity { fields["quantity"] = quantity ?? NSNull() }
        if let assignedTo { fields["assignedTo"] = assignedTo ?? NSNull() }

        item(tripId, listId, itemId).updateData(fields)
    }

    func moveItem(
        tripId: String, listId: String, itemId: String, position: Double
    ) {
        // No version bump — position is orthogonal to content, and bumping
        // would make a reorder conflict with a concurrent rename.
        item(tripId, listId, itemId).updateData([
            "position": position,
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    /// Hard delete. Items are small and disposable; the soft-delete machinery
    /// exists for lists only.
    func deleteItem(tripId: String, listId: String, itemId: String) {
        item(tripId, listId, itemId).delete()
    }

    /// Rewrites every item to clean multiples of `spacing`. Called only when
    /// repeated midpoint splits have collapsed a gap below Double precision —
    /// takes roughly 50 reorders into the same gap, so most lists never see it.
    func renormalizePositions(
        tripId: String, listId: String, orderedItemIds: [String]
    ) {
        guard !orderedItemIds.isEmpty else { return }

        let positions = ChecklistPosition.normalized(count: orderedItemIds.count)
        let batch = db.batch()

        for (itemId, position) in zip(orderedItemIds, positions) {
            batch.updateData(
                ["position": position],
                forDocument: item(tripId, listId, itemId)
            )
        }

        batch.commit()
    }
}

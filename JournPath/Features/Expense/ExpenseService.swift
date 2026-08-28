import FirebaseFirestore
import Foundation

/// Writes only. Listeners live in `ExpenseStore`.
///
/// Payloads are built as explicit dictionaries rather than encoding `Expense`,
/// so the client/server field split is auditable in one place: if a server-owned
/// key isn't typed out below, it cannot leak into a client write.
struct ExpenseService {

    enum ServiceError: LocalizedError {
        case notSignedIn
        case splitsDontBalance(remaining: Int)
        case exactSplitNeedsReview
        case missingId

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "You need to be signed in to save an expense."
            case .splitsDontBalance:
                return "The shares don't add up to the total."
            case .exactSplitNeedsReview:
                return "Update the exact amounts before saving this change."
            case .missingId:
                return "This expense hasn't been saved yet."
            }
        }
    }

    /// Which fields an edit touched. Drives what gets written and whether the
    /// server has to reconvert. See the edit-class table in the feature brief.
    enum EditClass {
        /// title, notes, category — no reconversion, no ledger recompute.
        case metadata
        /// amount, currency, spentAt — reconvert and recompute.
        case money
        /// split type, participants, amounts — recompute.
        case split
        /// paidBy only — splits untouched, ledger still recomputes.
        case payer
    }

    private var db: Firestore { Firestore.firestore() }

    private func collection(tripId: String) -> CollectionReference {
        db.collection("trips").document(tripId).collection("expenses")
    }

    // MARK: - Create

    @discardableResult
    func create(_ draft: ExpenseDraft, in tripId: String, by uid: String) throws -> String {
        guard ExpenseSplitMath.isValid(splits: draft.splits, amountMinor: draft.amountMinor) else {
            throw ServiceError.splitsDontBalance(
                remaining: ExpenseSplitMath.remaining(
                    splits: draft.splits, amountMinor: draft.amountMinor
                )
            )
        }

        let ref = collection(tripId: tripId).document()

        var payload = clientFields(from: draft)
        payload["createdBy"] = uid
        payload["createdAt"] = FieldValue.serverTimestamp()
        payload["clientCreatedAt"] = Timestamp(date: Date())
        payload["updatedAt"] = FieldValue.serverTimestamp()
        payload["version"] = 1

        // Deliberately absent: baseAmountMinor, baseSplits, rateUsed, rateDocId,
        // rateStatus, needsReview. The trigger owns all six.

        ref.setData(payload, merge: true) { error in
            if let error {
                AppLogger.store.error("Expense create failed: \(error.localizedDescription)")
            }
        }

        return ref.documentID
    }

    // MARK: - Update

    /// `expectedVersion` is the version the edit was based on. Rules require the
    /// incoming write to be exactly one higher, so a stale offline edit is
    /// rejected server-side instead of overwriting someone else's newer change.
    func update(
        _ draft: ExpenseDraft,
        id: String,
        in tripId: String,
        editClass: EditClass,
        expectedVersion: Int
    ) throws {
        switch editClass {
        case .money, .split:
            guard ExpenseSplitMath.isValid(splits: draft.splits, amountMinor: draft.amountMinor) else {
                throw ServiceError.splitsDontBalance(
                    remaining: ExpenseSplitMath.remaining(
                        splits: draft.splits, amountMinor: draft.amountMinor
                    )
                )
            }
        case .metadata, .payer:
            break
        }

        var payload: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp(),
            "version": expectedVersion + 1,
        ]

        switch editClass {
        case .metadata:
            // rateStatus stays final, splits untouched, no recompute.
            payload["title"] = draft.title
            payload["notes"] = draft.notes as Any? ?? FieldValue.delete()
            payload["category"] = draft.category?.rawValue as Any? ?? FieldValue.delete()

        case .payer:
            // Splits deliberately untouched. The trigger still recomputes the
            // ledger because who fronted the money changed.
            payload["paidBy"] = draft.paidBy

        case .money, .split:
            payload = payload.merging(clientFields(from: draft)) { _, new in new }
        }

        collection(tripId: tripId).document(id).updateData(payload) { error in
            if let error {
                AppLogger.store.error("Expense update failed: \(error.localizedDescription)")
            }
        }
    }

    /// Update a single person's share without touching anyone else's.
    ///
    /// Dotted field paths merge per key, so two people editing different shares
    /// concurrently both survive. Only safe for `.exact` — for equal and
    /// percentage the shares are derived, so a single-key write would desync
    /// them from the stored intent.
    func updateShare(
        uid: String,
        amountMinor: Int,
        expenseId: String,
        in tripId: String,
        expectedVersion: Int
    ) {
        collection(tripId: tripId).document(expenseId).updateData([
            "splits.\(uid)": amountMinor,
            "updatedAt": FieldValue.serverTimestamp(),
            "version": expectedVersion + 1,
        ]) { error in
            if let error {
                AppLogger.store.error("Share update failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Delete

    /// Hard delete. The trigger rebuilds the ledger without it.
    func delete(id: String, in tripId: String) {
        collection(tripId: tripId).document(id).delete { error in
            if let error {
                AppLogger.store.error("Expense delete failed: \(error.localizedDescription)")
            }
        }
    }

    /// Delete all expenses associated with an activity.
    func deleteForActivity(activityId: String, in tripId: String) async throws {
        let snapshot = try await collection(tripId: tripId)
            .whereField("activityId", isEqualTo: activityId)
            .getDocuments()
            
        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Payload

    /// Every field the client is allowed to write, and nothing else.
    private func clientFields(from draft: ExpenseDraft) -> [String: Any] {
        var payload: [String: Any] = [
            "title": draft.title,
            "paidBy": draft.paidBy,
            "amountMinor": draft.amountMinor,
            "currency": draft.currency,
            "currencyExponent": draft.currencyExponent,
            "spentAt": Timestamp(date: draft.spentAt),
            "splitType": draft.splitType.rawValue,
            "splits": draft.splits,
        ]

        payload["notes"] = draft.notes as Any? ?? FieldValue.delete()
        payload["category"] = draft.category?.rawValue as Any? ?? FieldValue.delete()
        payload["activityId"] = draft.activityId as Any? ?? FieldValue.delete()

        // Intent fields. Cleared when they don't apply, so a type change can't
        // leave stale percentages behind for the server to validate against.
        payload["equalParticipants"] = draft.splitType == .equal
            ? draft.equalParticipants.sorted()
            : FieldValue.delete()

        payload["splitPercentsBp"] = draft.splitType == .percentage
            ? draft.splitPercentsBp
            : FieldValue.delete()

        return payload
    }
}

// MARK: - Draft

/// What the form produces. Only client-owned fields, all money as integers.
struct ExpenseDraft {
    var title: String
    var notes: String?
    var category: ExpenseCategory?
    var activityId: String?
    var paidBy: String

    var amountMinor: Int
    var currency: String
    var currencyExponent: Int
    var spentAt: Date

    var splitType: SplitType
    var splits: [String: Int]
    var equalParticipants: [String]
    var splitPercentsBp: [String: Int]
}

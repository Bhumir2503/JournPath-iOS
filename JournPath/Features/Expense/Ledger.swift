import FirebaseFirestore
import Foundation

// MARK: - Model

/// Server-written read model at `trips/{tripId}/ledger/current`.
/// The client never writes this — it's fully recomputed by the Cloud Function
/// on every expense or settlement change.
struct Ledger: Codable, Hashable {
    var baseCurrency: String
    var baseCurrencyExponent: Int

    /// uid -> net position in base minor units.
    /// Positive means owed, negative means owes. Always sums to zero.
    var balances: [String: Int]

    /// Simplified pairwise debts — a suggestion, not a record. Recomputed from
    /// scratch each time, so it changes as expenses are added. Nothing is
    /// actually settled until a settlement document exists.
    var transfers: [LedgerTransfer]

    /// Expenses left out of the balances: awaiting a rate, or flagged for review.
    var excludedExpenseIds: [String]

    /// Total expense documents the recompute read — not the number included.
    /// Diverging from the client's own count means the ledger is stale.
    var expenseCountSeen: Int

    @ServerTimestamp var computedAt: Timestamp?
}

struct LedgerTransfer: Codable, Hashable, Identifiable {
    var from: String
    var to: String
    var amountMinor: Int

    var id: String { "\(from)>\(to)>\(amountMinor)" }
}

// MARK: - Store

@Observable
@MainActor
final class LedgerStore {

    private(set) var ledger: Ledger?
    private(set) var isLoading = true

    let tripId: String
    @ObservationIgnored private var listener: ListenerRegistration?

    init(tripId: String) {
        self.tripId = tripId
        start()
    }

    deinit {
        listener?.remove()
    }

    private func start() {
        listener?.remove()

        listener = Firestore.firestore()
            .collection("trips").document(tripId)
            .collection("ledger").document("current")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                defer { self.isLoading = false }

                if let error {
                    AppLogger.store.error("Ledger listener failed: \(error.localizedDescription)")
                    return
                }

                // Absent until the first expense triggers a recompute.
                guard let snapshot, snapshot.exists else {
                    self.ledger = nil
                    return
                }

                do {
                    self.ledger = try snapshot.data(as: Ledger.self, with: .estimate)
                } catch {
                    AppLogger.store.error("Failed to decode ledger: \(error.localizedDescription)")
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Derived

    func balance(for uid: String) -> Int {
        ledger?.balances[uid] ?? 0
    }

    /// Transfers this person is party to, either direction.
    func transfers(involving uid: String) -> [LedgerTransfer] {
        ledger?.transfers.filter { $0.from == uid || $0.to == uid } ?? []
    }

    var baseCurrency: String { ledger?.baseCurrency ?? "USD" }
}

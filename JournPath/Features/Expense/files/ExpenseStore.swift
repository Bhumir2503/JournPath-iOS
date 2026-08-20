import FirebaseFirestore
import Foundation

/// Owns the expenses listener for one trip. Writes go through `ExpenseService`.
@Observable
@MainActor
final class ExpenseStore {

    private(set) var expenses: [Expense] = []
    private(set) var isLoading = true
    private(set) var loadError: String?

    let tripId: String

    @ObservationIgnored private var listener: ListenerRegistration?

    init(tripId: String) {
        self.tripId = tripId
        start()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Listener

    private func start() {
        listener?.remove()

        listener = Firestore.firestore()
            .collection("trips").document(tripId)
            .collection("expenses")
            .order(by: "spentAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    AppLogger.store.error("Expense listener failed: \(error.localizedDescription)")
                    self.loadError = error.localizedDescription
                    self.isLoading = false
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }

                // `.estimate` so a locally-written doc renders immediately with a
                // best-guess timestamp instead of nil while the server confirms.
                self.expenses = documents.compactMap { doc in
                    do {
                        return try doc.data(as: Expense.self, with: .estimate)
                    } catch {
                        AppLogger.store.error(
                            "Failed to decode expense \(doc.documentID): \(error.localizedDescription)"
                        )
                        return nil
                    }
                }

                self.loadError = nil
                self.isLoading = false
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Lookup

    func expense(id: String) -> Expense? {
        expenses.first { $0.id == id }
    }

    /// Expenses the server has pulled out of the balance calculation. Drives the
    /// amber "amounts don't add up" treatment.
    var flagged: [Expense] {
        expenses.filter { $0.isFlagged }
    }

    /// Awaiting conversion. Visible in the list, absent from balances — worth
    /// showing a "rate pending" chip so it doesn't read as a lost expense.
    var awaitingRate: [Expense] {
        expenses.filter { $0.effectiveRateStatus == .pending && !$0.isFlagged }
    }

    // MARK: - Totals (base currency minor units)

    /// Only converted, unflagged expenses count — the same rule the server's
    /// ledger applies, so these figures agree with the balance hero.
    private var ledgerReady: [Expense] {
        expenses.filter(\.countsTowardLedger)
    }

    var tripTotalBase: Int {
        ledgerReady.compactMap(\.baseAmountMinor).reduce(0, +)
    }

    func totalPaid(by uid: String) -> Int {
        ledgerReady
            .filter { $0.paidBy == uid }
            .compactMap(\.baseAmountMinor)
            .reduce(0, +)
    }

    func totalShare(for uid: String) -> Int {
        ledgerReady
            .compactMap { $0.baseSplits?[uid] }
            .reduce(0, +)
    }
}

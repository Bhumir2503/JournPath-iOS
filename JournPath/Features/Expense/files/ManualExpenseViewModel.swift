import FirebaseFirestore
import Foundation

/// Owns every intent for the add-expense form.
///
/// All money is `Int` minor units. `amountText` is the raw keypad string and is
/// the only place a decimal point exists; it's parsed to minor units on every
/// change and never routed through `Double`.
@Observable
@MainActor
final class ManualExpenseViewModel {

    // MARK: - Input

    var amountText = "" { didSet { syncSplitsToIntent() } }
    var selectedCurrency: String { didSet { handleCurrencyChange(from: oldValue) } }
    var spentAt = Date()
    var title = ""
    var notes = ""
    var category: ExpenseCategory = .shopping
    var activityId: String?

    var paidById: String = "" { didSet { syncSplitsToIntent() } }
    var splitType: SplitType = .equal { didSet { handleSplitTypeChange() } }

    /// Intent for `.equal`.
    var equalParticipants: Set<String> = [] { didSet { syncSplitsToIntent() } }
    /// Intent for `.percentage`, in basis points. 2550 = 25.5%.
    var percentBp: [String: Int] = [:] { didSet { syncSplitsToIntent() } }
    /// Amounts for `.exact`, already in minor units.
    var exactSplits: [String: Int] = [:] { didSet { syncSplitsToIntent() } }

    // MARK: - Derived state

    /// The exact map that will be written. Computed from intent for equal and
    /// percentage, typed directly for exact.
    private(set) var splits: [String: Int] = [:]
    private(set) var splitError: String?

    var invalidAttempts = 0
    var isSaving = false
    var saveError: String?

    // MARK: - Dependencies

    private let tripId: String
    private let currentUid: String
    private let participantIds: [String]
    private let service = ExpenseService()

    init(tripId: String, currentUid: String, participantIds: [String], defaultCurrency: String = "USD") {
        self.tripId = tripId
        self.currentUid = currentUid
        self.participantIds = participantIds
        self.selectedCurrency = defaultCurrency
        self.paidById = currentUid

        // Everyone in by default — a split containing only the payer has zero
        // net effect and is almost never what someone means.
        self.equalParticipants = Set(participantIds)
        syncSplitsToIntent()
    }

    // MARK: - Money

    var currencyExponent: Int { Money.exponent(for: selectedCurrency) }
    var currencySymbol: String { Money.symbol(for: selectedCurrency) }

    var amountMinor: Int {
        Money.minorUnits(from: amountText, currency: selectedCurrency) ?? 0
    }

    var formattedAmount: String {
        Money.groupedDisplay(rawText: amountText, currency: selectedCurrency)
    }

    func formatted(_ minor: Int) -> String {
        Money.formatted(minor, currency: selectedCurrency)
    }

    // MARK: - Split derivation

    /// Recompute `splits` whenever anything it depends on changes.
    ///
    /// This is the live preview, and it uses the identical rules the server will
    /// use for `baseSplits` — including the remainder landing on the payer — so
    /// what the user sees is exactly what gets stored.
    private func syncSplitsToIntent() {
        do {
            switch splitType {
            case .equal:
                splits = try ExpenseSplitMath.equalSplits(
                    amountMinor: amountMinor,
                    participants: Array(equalParticipants),
                    paidBy: paidById
                )

            case .percentage:
                // Don't surface a "must total 100%" error while the user is still
                // typing — leave splits empty and let the footer show remaining.
                let total = percentBp.values.reduce(0, +)
                guard total == 10_000 else {
                    splits = [:]
                    splitError = nil
                    return
                }
                splits = try ExpenseSplitMath.percentageSplits(
                    amountMinor: amountMinor,
                    percentsBp: percentBp,
                    paidBy: paidById
                )

            case .exact:
                splits = exactSplits.filter { $0.value != 0 }
            }
            splitError = nil
        } catch {
            splits = [:]
            splitError = error.localizedDescription
        }
    }

    private func handleSplitTypeChange() {
        switch splitType {
        case .equal:
            if equalParticipants.isEmpty { equalParticipants = Set(participantIds) }
        case .percentage:
            if percentBp.isEmpty { percentBp = evenBasisPoints() }
        case .exact:
            // Seed from whatever the previous type produced, so switching to
            // exact starts from the current allocation rather than blank.
            if exactSplits.isEmpty { exactSplits = splits }
        }
        syncSplitsToIntent()
    }

    /// Even percentage split with the odd basis points given to the payer, so the
    /// default always totals exactly 10000.
    private func evenBasisPoints() -> [String: Int] {
        let uids = participantIds.sorted()
        guard !uids.isEmpty else { return [:] }

        let base = 10_000 / uids.count
        var result = [String: Int]()
        for uid in uids { result[uid] = base }

        let remainder = 10_000 - (base * uids.count)
        if remainder != 0, let absorber = ExpenseSplitMath.absorber(in: result, paidBy: paidById) {
            result[absorber, default: 0] += remainder
        }
        return result
    }

    private func handleCurrencyChange(from old: String) {
        guard old != selectedCurrency else { return }

        // Zero-decimal currency: drop a fraction the user already typed.
        if currencyExponent == 0, amountText.contains(".") {
            amountText = String(amountText.split(separator: ".")[0])
        }

        // Exact amounts were entered in the old currency's minor units. They
        // don't carry over — 2500 means $25.00 or ¥2,500 depending on which.
        if splitType == .exact, Money.exponent(for: old) != currencyExponent {
            exactSplits = [:]
        }

        UserDefaults.standard.set(selectedCurrency, forKey: "currency_\(tripId)")
        syncSplitsToIntent()
    }

    // MARK: - Per-participant helpers

    func share(for uid: String) -> Int? { splits[uid] }

    func percentString(for uid: String) -> String {
        guard let bp = percentBp[uid] else { return "" }
        return (Double(bp) / 100).formatted(.number.precision(.fractionLength(0...2)))
    }

    func setPercent(_ text: String, for uid: String) {
        guard let value = Double(text) else {
            percentBp[uid] = nil
            return
        }
        percentBp[uid] = Int((value * 100).rounded())
    }

    func exactString(for uid: String) -> String {
        guard let minor = exactSplits[uid] else { return "" }
        return Money.decimalString(minor, currency: selectedCurrency)
    }

    func setExact(_ text: String, for uid: String) {
        exactSplits[uid] = Money.minorUnits(from: text, currency: selectedCurrency)
    }

    /// Largest value this participant can take without overshooting the total.
    func remainingLimit(excluding uid: String) -> Int {
        let others = exactSplits.filter { $0.key != uid }.values.reduce(0, +)
        return max(0, amountMinor - others)
    }

    func remainingPercentLimit(excluding uid: String) -> Double {
        let others = percentBp.filter { $0.key != uid }.values.reduce(0, +)
        return max(0, Double(10_000 - others) / 100)
    }

    // MARK: - Validation

    var amountIsEmpty: Bool { amountMinor == 0 }

    /// Signed shortfall in minor units. Positive means unassigned.
    var remaining: Int {
        ExpenseSplitMath.remaining(splits: splits, amountMinor: amountMinor)
    }

    var remainingPercentBp: Int {
        10_000 - percentBp.values.reduce(0, +)
    }

    var isFullySplit: Bool {
        switch splitType {
        case .percentage: return remainingPercentBp == 0 && remaining == 0
        default: return remaining == 0 && !splits.isEmpty
        }
    }

    /// Exact equality, not a 0.01 tolerance — the server's check is
    /// `sum(splits) == amountMinor`, and anything looser lets through a save
    /// that gets flagged and dropped from the ledger.
    var canSubmit: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard amountMinor != 0 else { return false }
        guard splitError == nil else { return false }
        return ExpenseSplitMath.isValid(splits: splits, amountMinor: amountMinor)
    }

    // MARK: - Save

    func save() -> Bool {
        guard canSubmit else {
            invalidAttempts += 1
            return false
        }

        let draft = ExpenseDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes,
            category: category,
            activityId: activityId,
            paidBy: paidById,
            amountMinor: amountMinor,
            currency: selectedCurrency,
            currencyExponent: currencyExponent,
            spentAt: spentAt,
            splitType: splitType,
            splits: splits,
            equalParticipants: Array(equalParticipants),
            splitPercentsBp: percentBp
        )

        isSaving = true
        defer { isSaving = false }

        do {
            try service.create(draft, in: tripId, by: currentUid)
            return true
        } catch {
            saveError = error.localizedDescription
            AppLogger.store.error("Expense save failed: \(error.localizedDescription)")
            return false
        }
    }
}

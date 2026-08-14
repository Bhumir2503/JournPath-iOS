import Foundation
import StoreKit

@MainActor
@Observable
final class PurchaseService {

    static let shared = PurchaseService()

    // MARK: State

    private(set) var products: [Product] = []
    private(set) var phase: Phase = .idle

    /// Which trip `phase` refers to. Without this, a failure on trip A is
    /// still on screen when the user opens trip B's paywall.
    private(set) var phaseTripID: String?

    /// Protocol-typed so `StubRedeemer` can be dropped in for testing.
    var redeemer: PurchaseRedeeming = APIRedeemer()

    @ObservationIgnored private var listener: Task<Void, Never>?

    private init() {}

    // MARK: Types

    enum Phase: Equatable {
        case idle
        case loadingProducts
        /// Apple's sheet is up. The customer can still back out.
        case purchasing
        /// Charged. Recording the grant. Not cancellable.
        case confirming
        /// Ask to Buy. No money has moved; approval may take days.
        case awaitingApproval
        case failed(Failure)
    }

    enum Failure: Equatable {
        case productsUnavailable
        case notAllowed
        case network
        /// Charged, but the server didn't record it. StoreKit still holds
        /// the transaction and will re-deliver it on a later launch.
        case recordingFailed
        case unknown(String)

        /// Whether the customer's card was charged. Drives both the wording
        /// and the styling — a charged-but-unfinished purchase must not look
        /// like a failure, or people buy a second time.
        nonisolated var paymentTaken: Bool { self == .recordingFailed }

        nonisolated var message: String {
            switch self {
            case .productsUnavailable:
                "This upgrade isn't available right now. Try again in a few minutes."
            case .notAllowed:
                "Purchases are turned off on this device. Check Screen Time settings."
            case .network:
                "No connection to the App Store. Check your network and try again."
            case .recordingFailed:
                "Your payment went through. We're still unlocking the trip — reopen JournPath in a moment and it will finish on its own."
            case .unknown(let detail):
                detail
            }
        }
    }

    /// Thrown for genuine failures only. Cancelling and Ask to Buy are
    /// normal outcomes and never throw.
    struct PurchaseFailed: LocalizedError {
        let failure: Failure
        nonisolated var errorDescription: String? { failure.message }
        nonisolated var paymentTaken: Bool { failure.paymentTaken }
    }

    enum Outcome {
        case unlocked
        /// Backed out of Apple's sheet. Show nothing.
        case cancelled
        /// Ask to Buy. No money moved; approval may arrive days later.
        case pending
    }

    private enum RedeemError: Error {
        /// StoreKit couldn't verify Apple's signature. Don't grant, don't finish.
        case unverified
        /// Recovered a transaction with no record of which trip it was for.
        case unknownTrip
        case serverRejected
    }

    // MARK: Lifecycle

    /// Call once at app launch, before any purchase UI exists.
    func start() {
        guard listener == nil else { return }

        listener = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.redeemQuietly(result)
            }
        }

        Task {
            await loadProducts()
            await sweepUnfinished()
        }
    }

    // MARK: Products

    func loadProducts() async {
        phase = .loadingProducts
        do {
            products = try await Product.products(for: ProductID.all)
            phase = products.isEmpty ? .failed(.productsUnavailable) : .idle
        } catch {
            phase = .failed(.network)
        }
    }

    var tripUnlock: Product? {
        products.first { $0.id == ProductID.tripUnlock }
    }

    var tripUnlockPrice: String? {
        tripUnlock?.displayPrice
    }

    // MARK: Purchasing

    @discardableResult
    func purchaseTripUnlock(for tripID: String) async throws -> Outcome {
        guard let product = tripUnlock else {
            throw enterFailure(.productsUnavailable, tripID: tripID)
        }
        return try await purchase(product, tripID: tripID)
    }

    @discardableResult
    func purchase(_ product: Product, tripID: String) async throws -> Outcome {
        phase = .purchasing
        phaseTripID = tripID

        // --- Stage 1: Apple's payment sheet ---
        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            throw enterFailure(map(error), tripID: tripID)
        }

        switch result {

        case .success(let verification):
            // Money has moved. Everything below is recovery-critical.
            phase = .confirming

            do {
                try await redeem(verification, tripID: tripID)
            } catch {
                print("[Purchases] Redeem failed: \(error)")
                throw enterFailure(.recordingFailed, tripID: tripID)
            }

            reset()
            return .unlocked

        case .pending:
            // No money moved. Not an error.
            phase = .awaitingApproval
            return .pending

        case .userCancelled:
            reset()
            return .cancelled

        @unknown default:
            reset()
            return .cancelled
        }
    }

    func restore() async {
        await sweepUnfinished()
        reset()
    }

    func clearFailure() {
        if case .failed = phase { reset() }
    }

    // MARK: Phase helpers

    private func reset() {
        phase = .idle
        phaseTripID = nil
    }

    private func enterFailure(_ failure: Failure, tripID: String?) -> PurchaseFailed {
        phase = .failed(failure)
        phaseTripID = tripID
        return PurchaseFailed(failure: failure)
    }

    private func map(_ error: Error) -> Failure {
        if let error = error as? Product.PurchaseError {
            switch error {
            case .productUnavailable: return .productsUnavailable
            case .purchaseNotAllowed: return .notAllowed
            default: return .unknown(error.localizedDescription)
            }
        }
        if let error = error as? StoreKitError {
            if case .networkError = error { return .network }
            return .unknown(error.localizedDescription)
        }
        return .unknown(error.localizedDescription)
    }

    // MARK: Redemption

    private func redeem(
        _ result: VerificationResult<Transaction>,
        tripID: String?
    ) async throws {
        guard case .verified(let transaction) = result else {
            // Leave it unfinished. A transient signature problem will verify
            // on a later launch; a forged one never grants.
            throw RedeemError.unverified
        }

        // `/purchase/redeem` requires a tripId, so a recovered transaction
        // needs one too. Record the pairing the instant we have a
        // transaction ID — before the network call that might fail.
        if let tripID {
            PendingTrips.record(tripID: tripID, for: transaction.id)
        }

        guard let tripID = tripID ?? PendingTrips.tripID(for: transaction.id) else {
            // Charged on a device we no longer have state for — a reinstall
            // between purchase and redemption. Nothing to do client-side.
            print("[Purchases] No trip recorded for transaction \(transaction.id)")
            throw RedeemError.unknownTrip
        }

        do {
            try await redeemer.redeem(
                signedTransaction: result.jwsRepresentation,
                tripId: tripID
            )
        } catch {
            throw RedeemError.serverRejected
        }

        // Only now. Finishing before the server confirms discards the
        // only retry mechanism there is.
        await transaction.finish()
        PendingTrips.clear(for: transaction.id)
    }

    /// Background redemption — no UI, failures left for the next attempt.
    private func redeemQuietly(_ result: VerificationResult<Transaction>) async {
        do {
            try await redeem(result, tripID: nil)
        } catch {
            print("[Purchases] Background redeem deferred: \(error)")
        }
    }

    private func sweepUnfinished() async {
        for await result in Transaction.unfinished {
            await redeemQuietly(result)
        }
    }
}

// MARK: - Pending trip mapping

/// Remembers which trip a transaction was bought for, so a redemption that
/// fails and is retried on a later launch still knows where to spend.
///
/// Deliberately `UserDefaults` — this must survive a crash and a relaunch,
/// and it holds no sensitive data.
private enum PendingTrips {
    private static let key = "purchases.pendingTripIDs"

    private static var map: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func record(tripID: String, for transactionID: UInt64) {
        map["\(transactionID)"] = tripID
    }

    static func tripID(for transactionID: UInt64) -> String? {
        map["\(transactionID)"]
    }

    static func clear(for transactionID: UInt64) {
        map["\(transactionID)"] = nil
    }
}

// MARK: - Paywall mapping

extension PurchaseService {

    /// What the sheet for `tripID` should render.
    func paywallState(for tripID: String) -> PaywallState {
        if let phaseTripID, phaseTripID != tripID {
            return tripUnlockPrice == nil ? .loading : .ready
        }

        switch phase {
        case .idle:
            return tripUnlockPrice == nil ? .loading : .ready
        case .loadingProducts:
            return .loading
        case .purchasing:
            return .purchasing
        case .confirming:
            return .confirming
        case .awaitingApproval:
            return .awaitingApproval
        case .failed(let failure):
            return .failed(message: failure.message, paymentTaken: failure.paymentTaken)
        }
    }
}

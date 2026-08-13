import Foundation
import StoreKit

@MainActor
@Observable
final class PurchaseService {

    static let shared = PurchaseService()

    // MARK: State

    private(set) var products: [Product] = []
    private(set) var phase: Phase = .idle

    /// Swap the stub for your API implementation when the endpoint lands.
    var redeemer = APIRedeemer()

    @ObservationIgnored private var listener: Task<Void, Never>?

    private init() {}

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
        var paymentTaken: Bool { self == .recordingFailed }

        var message: String {
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

    private enum RedeemError: Error {
        /// StoreKit couldn't verify Apple's signature. Don't grant, don't finish.
        case unverified
        case serverRejected
    }

    // MARK: Lifecycle

    /// Call once at app launch, before any purchase UI exists.
    ///
    /// The listener has to run for the whole session. It's how Ask to Buy
    /// approvals, purchases made on another device, and transactions that
    /// failed to redeem earlier get delivered.
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

    deinit { listener?.cancel() }

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

    /// Buys one credit and spends it on `tripID` in a single server call.
    ///
    /// Returns true only once the server has confirmed. Even then, the UI
    /// should unlock off the Firestore listener rather than this value —
    /// a consumable leaves no trace in StoreKit, so the trip document is
    /// the only durable record.
    @discardableResult
    func purchaseTripUnlock(for tripID: String) async throws -> Bool {
        guard let product = tripUnlock else {
            phase = .failed(.productsUnavailable)
            throw RedeemError.unverified
        }
        return try await purchase(product, tripID: tripID)
    }

    @discardableResult
    func purchase(_ product: Product, tripID: String) async throws -> Bool {
        phase = .purchasing

        do {
            switch try await product.purchase() {

            case .success(let verification):
                // Money has moved. Everything below is recovery-critical.
                phase = .confirming
                try await redeem(verification, tripID: tripID)
                phase = .idle
                return true

            case .pending:
                phase = .awaitingApproval
                throw Product.PurchaseError.purchaseNotAllowed

            case .userCancelled:
                // Not an error. Say nothing, show nothing.
                phase = .idle
                throw Product.PurchaseError.purchaseNotAllowed

            @unknown default:
                phase = .idle
                throw Product.PurchaseError.purchaseNotAllowed
            }

        } catch let error as RedeemError {
            // Charged but not recorded. Distinct from a failed purchase.
            print("[Purchases] Redeem failed: \(error)")
            phase = .failed(.recordingFailed)
            throw RedeemError.unverified

        } catch let error as Product.PurchaseError {
            switch error {
            case .productUnavailable:
                phase = .failed(.productsUnavailable)
            case .purchaseNotAllowed:
                phase = .failed(.notAllowed)
            default:
                phase = .failed(.unknown(error.localizedDescription))
            }
            throw Product.PurchaseError.purchaseNotAllowed

        } catch let error as StoreKitError {
            if case .networkError = error {
                phase = .failed(.network)
            } else {
                phase = .failed(.unknown(error.localizedDescription))
            }
            throw Product.PurchaseError.purchaseNotAllowed

        } catch {
            phase = .failed(.unknown(error.localizedDescription))
            throw Product.PurchaseError.purchaseNotAllowed
        }
    }

    /// Re-sends anything StoreKit still holds, then lets the caller refresh
    /// server state.
    ///
    /// Consumables aren't restorable in the classic sense — they never appear
    /// in `currentEntitlements`. This is a repair path for a transaction that
    /// never reached the server, and the control App Review looks for.
    func restore() async {
        phase = .confirming
        await sweepUnfinished()
        phase = .idle
    }

    func clearFailure() {
        if case .failed = phase { phase = .idle }
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

        do {
            try await redeemer.redeem(
                signedTransaction: result.jwsRepresentation,
                tripID: tripID
            )
        } catch {
            throw RedeemError.serverRejected
        }

        // Only now. Finishing before the server confirms discards the
        // only retry mechanism there is.
        await transaction.finish()
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

// MARK: - Paywall mapping

extension PurchaseService {

    /// Translates the service's phase into what the sheet renders.
    var paywallState: PaywallState {
        switch phase {
        case .idle:
            tripUnlockPrice == nil ? .loading : .ready
        case .loadingProducts:
            .loading
        case .purchasing:
            .purchasing
        case .confirming:
            .confirming
        case .awaitingApproval:
            .awaitingApproval
        case .failed(let failure):
            .failed(message: failure.message, paymentTaken: failure.paymentTaken)
        }
    }
}

import Foundation
import Observation

// Everything the sheet needs to know about what's happening.
// Derived from `PurchaseService.phase` — see `paywallState`.
enum PaywallState: Equatable {

    // Product metadata hasn't arrived from the App Store yet.
    case loading

    // Ready to buy.
    case ready

    // Apple's payment sheet is up. The user can still back out.
    case purchasing

    // Paid. Recording the grant. The sheet must not be dismissible here.
    case confirming

    // Ask to Buy — approval may arrive minutes or days later.
    case awaitingApproval

    // `paymentTaken` distinguishes "the purchase failed" from "you were
    // charged but we haven't finished unlocking yet". They read very
    // differently to a customer and must not look the same.
    case failed(message: String, paymentTaken: Bool)

    var isBusy: Bool {
        switch self {
        case .loading, .purchasing, .confirming: true
        default: false
        }
    }
}


enum ProductID {

    /// Consumable. Grants one trip credit to the user's wallet.
    static let tripUnlock = "com.bentertainment.journpath.credits.1"

    static var all: [String] { [tripUnlock] }
}

@MainActor
@Observable
final class PaywallVM {

    private let purchases: PurchaseService
    var tripID: String = ""

    

    let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    let privacyURL = URL(string: "https://bentertainment.co/privacy")!

    init(purchases: PurchaseService? = nil) {
        self.purchases = purchases ?? .shared
    }

    // MARK: - Derived State

    var state: PaywallState {
        purchases.paywallState(for: tripID)
    }

    var cantLoadProducts: Bool {
        guard purchases.tripUnlockPrice == nil else { return false }
        switch purchases.phase {
        case .failed(.productsUnavailable), .failed(.network):
            return true
        default:
            return false
        }
    }

    var tripUnlockPrice: String? {
        purchases.tripUnlockPrice
    }

    var isPriceLoading: Bool {
        purchases.tripUnlockPrice == nil
    }

    /// Prevents duplicate purchases when payment was already taken or transaction is pending/busy.
    var isPurchaseDisabled: Bool {
        switch state {
        case .loading, .purchasing, .confirming, .awaitingApproval:
            return true
        case .failed(_, let paymentTaken):
            return paymentTaken || isPriceLoading
        case .ready:
            return isPriceLoading
        }
    }

    var buttonTitle: String {
        switch state {
        case .awaitingApproval:
            return "AWAITING APPROVAL"
        case .failed(_, let paymentTaken) where paymentTaken:
            return "PAYMENT PROCESSED"
        default:
            return "UPGRADE THIS TRIP"
        }
    }

    var isDismissDisabled: Bool {
        state.isBusy
    }

    // MARK: - Actions

    func onAppear(tripID: String) async {
        self.tripID = tripID
        if purchases.tripUnlockPrice == nil {
            await purchases.loadProducts()
        }
    }

    func retryLoadProducts() async {
        await purchases.loadProducts()
    }

    func purchaseTripUnlock() async throws {
        guard !tripID.isEmpty else { return }
        let outcome = try await purchases.purchaseTripUnlock(for: tripID)
        switch outcome {
        case .unlocked:
            return
        case .cancelled, .pending:
            throw CancellationError()
        }
    }

    func restore() async {
        await purchases.restore()
    }
}

typealias PaywallViewModel = PaywallVM

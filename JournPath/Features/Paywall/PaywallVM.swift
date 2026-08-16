import Foundation
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



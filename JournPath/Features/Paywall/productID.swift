import Foundation

/// Product identifiers as configured in App Store Connect.
///
/// These must match exactly. Identifiers are permanent — once a product
/// exists in App Store Connect, its ID can never be deleted or reused.
enum ProductID {

    /// Consumable. Grants one trip credit to the user's wallet.
    static let tripUnlock = "com.bentertainment.journpath.credits.1"

    static var all: [String] { [tripUnlock] }
}

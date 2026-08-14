import Foundation

/// The one thing `PurchaseService` needs from the backend.
///
/// Implementations must be **idempotent**: the same signed transaction may
/// arrive more than once — on retry after a dropped response, on the next
/// launch, from a second device. The server keys on the Apple transaction
/// ID and grants at most once.
protocol PurchaseRedeeming {

    /// - Parameters:
    ///   - signedTransaction: The JWS representation, sent raw. The server
    ///     verifies Apple's signature itself; a client-decoded transaction
    ///     is trivially forgeable.
    ///   - tripId: The trip to unlock. Required by `/purchase/redeem`.
    func redeem(signedTransaction: String, tripId: String) async throws
}

// MARK: - Real implementation

struct APIRedeemer: PurchaseRedeeming {
    /// The request carries the Firebase ID token via `APIClient` — the
    /// server grants to the authenticated uid, never to one in the body.
    func redeem(signedTransaction: String, tripId: String) async throws {
        _ = try await APIClient.shared.post(
            "/purchase/redeem",
            body: [
                "signedTransaction": signedTransaction,
                "tripId": tripId,
            ]
        )
    }
}

// MARK: - Stub

/// For exercising the UI without a backend.
///
/// `succeeds: false` produces the "you were charged, we're still unlocking"
/// state — the one path that's otherwise hard to reach on purpose.
struct StubRedeemer: PurchaseRedeeming {

    var succeeds = true
    var delay: Duration = .milliseconds(600)

    func redeem(signedTransaction: String, tripId: String) async throws {
        try? await Task.sleep(for: delay)
        print("[Redeem] trip=\(tripId) jws=\(signedTransaction.prefix(24))…")
        if !succeeds { throw URLError(.timedOut) }
    }
}

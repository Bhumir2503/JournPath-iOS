import Foundation


protocol PurchaseRedeeming {
    func redeem(signedTransaction: String, tripID: String) async throws
}

// MARK: - Real API
struct APIRedeemer: PurchaseRedeeming {
    func redeem(signedTransaction: String, tripID: String) async throws {
        _ = try await APIClient.shared.post(
            "/purchase/apple",
            body: [
                "signedTransaction": signedTransaction,
                "tripId": tripID,
            ]
        )
    }
}

// MARK: - Stub
struct StubRedeemer: PurchaseRedeeming {

    var succeeds = true
    var delay: Duration = .milliseconds(600)

    func redeem(signedTransaction: String, tripID: String) async throws {
        try? await Task.sleep(for: delay)
        print("[Redeem] trip=\(tripID) jws=\(signedTransaction.prefix(24))…")
        if !succeeds { throw URLError(.timedOut) }
    }
}

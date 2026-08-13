import Foundation

// MARK: - Stub

/// Placeholder until `/purchases/redeem` exists.
///
/// Set `succeeds` to exercise both branches of the UI: `true` walks the
/// happy path, `false` produces the "you were charged, we're still
/// unlocking" state without needing a network at all.
struct StubRedeemer {

    var succeeds = true
    var delay: Duration = .milliseconds(600)

    func redeem(signedTransaction: String, tripID: String?) async throws {
        try? await Task.sleep(for: delay)

        print("[Redeem] trip=\(tripID ?? "none") jws=\(signedTransaction.prefix(24))…")

        if !succeeds {
            throw URLError(.timedOut)
        }
    }
}

// MARK: - Real implementation

/// Swap this in once the endpoint is live.
///
struct APIRedeemer {
    func redeem(signedTransaction: String, tripID: String?) async throws {
        var body: [String: Any] = ["signedTransaction": signedTransaction]
        if let tripID { body["tripId"] = tripID }
        _ = try await APIClient.shared.post("/purchases/redeem", body: body)
    }
}
///
/// The request must carry the Firebase ID token — the server grants to the
/// authenticated uid, never to a uid supplied in the body.

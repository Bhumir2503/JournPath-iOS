import FirebaseAppCheck
import FirebaseAuth
import FirebaseFunctions
import SwiftUI

class DeepLinkService {
    func handle(url: URL) -> [String]? {
        guard url.path.contains("join") else { return nil }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let queryItems = components.queryItems
        else { return nil }

        let tripId = queryItems.first(where: { $0.name == "tripId" })?.value
        let inviteToken = queryItems.first(where: { $0.name == "inviteToken" })?.value

        if let tripId, let inviteToken {
            return [tripId, inviteToken]
        }

        return nil
    }

    func joinTrip(tripId: String, inviteToken: String) async throws -> String {
        let url = URL(string: "https://api.usemyjourney.com/joinTrip")!

        // 1. Auth ID token — establishes WHO is calling. The Functions SDK attached
        //    this automatically; now we fetch and attach it by hand.
        guard let user = Auth.auth().currentUser else {
            throw URLError(.userAuthenticationRequired)
        }
        let idToken = try await user.getIDToken()

        // 2. App Check token — establishes the call came from your app. Also
        //    previously automatic; the VM middleware verifies this header.
        let appCheckToken = try await AppCheck.appCheck().token(forcingRefresh: false)

        // 3. Build the request.
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue(appCheckToken.token, forHTTPHeaderField: "X-Firebase-AppCheck")

        let body: [String: Any] = [
            "tripId": tripId,
            "inviteToken": inviteToken,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // 4. Send.
        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // TEMP debug — see exactly what came back
        print("STATUS:", http.statusCode)
        print("BODY:", String(data: responseData, encoding: .utf8) ?? "<non-utf8>")
        // 5. Handle non-2xx. Your server returns { "error": code, "message": ... }
        //    with the HTTP status mapped from the CallableError code.
        guard (200...299).contains(http.statusCode) else {
            if let errData = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                let message = errData["message"] as? String
            {
                throw NSError(
                    domain: "MyJourneyAPI",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            }
            throw URLError(.badServerResponse)
        }

        // 6. Your server wraps success as { "result": { success, tripId } }.
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
            let resultObj = json["result"] as? [String: Any],
            let verifiedTripId = resultObj["tripId"] as? String
        else {
            throw URLError(.badServerResponse)
        }

        return verifiedTripId
    }
}

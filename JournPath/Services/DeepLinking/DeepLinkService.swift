import FirebaseAppCheck
import FirebaseAuth
import FirebaseFunctions
import SwiftUI

struct InviteDetails {
    let tripId: String
    let token: String
}

class DeepLinkService {

    func handle(url: URL) -> InviteDetails? {
        // 1. Ensure path starts with /invite/trip/
        guard url.path.contains("/invite/trip/") else { return nil }

        // 2. Extract tripId from the path
        // URL path: /invite/trip/abc123xyz
        let pathComponents = url.pathComponents
        guard let tripIndex = pathComponents.firstIndex(of: "trip"),
            tripIndex + 1 < pathComponents.count
        else { return nil }

        let tripId = pathComponents[tripIndex + 1]

        // 3. Extract token from query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let token = components.queryItems?.first(where: { $0.name == "token" })?.value
        else { return nil }

        return InviteDetails(tripId: tripId, token: token)
    }

    func joinTrip(tripId: String, inviteToken: String) async throws(APIError) -> String {
        // 1. Define the payload
        let body: [String: Any] = [
            "tripId": tripId,
            "inviteToken": inviteToken,
        ]

        let response = try await APIClient.shared.post(
            "/trip/join",
            body: body
        )

        guard let result = response["result"] as? [String: Any],
            let verifiedTripId = result["tripId"] as? String
        else {
            throw APIError.invalidResponse
        }

        return verifiedTripId
    }
}

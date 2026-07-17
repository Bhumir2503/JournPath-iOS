import FirebaseAppCheck
import FirebaseAuth
import Foundation

/// Thin client for the JournPath API. Owns token fetching, request
/// building, and response decoding so services only supply a path + payload.
final class APIClient {

    static let shared = APIClient()

    private let baseURL = URL(string: "https://api.journpath.com")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// POSTs a JSON payload to the given path and returns the parsed JSON response.
    @discardableResult
    func post(
        _ path: String,
        body: [String: Any],
        requiresAuth: Bool = true,
        requiresAppCheck: Bool = true
    ) async throws(APIError) -> [String: Any] {
        do {
            let request = try await makeRequest(
                path: path,
                body: body,
                requiresAuth: requiresAuth,
                requiresAppCheck: requiresAppCheck
            )
            let (data, response) = try await session.data(for: request)

            // This will throw APIError.serverError if the backend sends an error
            return try parse(data: data, response: response)

        } catch let error as APIError {
            // 1. Pass-through: Keeps your backend error messages and status codes perfectly intact.
            throw error

        } catch is URLError {
            // 2. Network failures: Hardware level failures (like Airplane mode).
            throw .noInternetConnection

        } catch {
            // 3. Fallback: For JSON serialization failures or token fetching errors inside makeRequest.
            throw .serverError(status: 0, message: "An unexpected error occurred: \(error.localizedDescription)")
        }
    }

    // MARK: - Request Building

    /// Builds an authenticated request with the Auth + App Check tokens optionally.
    private func makeRequest(
        path: String,
        body: [String: Any],
        requiresAuth: Bool,
        requiresAppCheck: Bool
    ) async throws -> URLRequest {

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 1. Handle Auth Token Conditionally
        if requiresAuth {
            guard let user = Auth.auth().currentUser else {
                throw APIError.notAuthenticated
            }
            let idToken = try await user.getIDToken()
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        // 2. Handle App Check Token Conditionally
        if requiresAppCheck {
            let appCheckToken = try await AppCheck.appCheck().token(forcingRefresh: false)
            request.setValue(appCheckToken.token, forHTTPHeaderField: "X-Firebase-AppCheck")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Response Parsing

    private func parse(data: Data, response: URLResponse) throws -> [String: Any] {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard (200..<300).contains(http.statusCode) else {
            let message = json?["message"] as? String ?? json?["error"] as? String
            throw APIError.serverError(status: http.statusCode, message: message)
        }

        guard let json else {
            throw APIError.invalidResponse
        }

        return json
    }
}

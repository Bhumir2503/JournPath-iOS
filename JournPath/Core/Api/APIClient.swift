import FirebaseAppCheck
import FirebaseAuth
import Foundation

/// Thin client for the JournPath API. Owns token fetching, request
/// building, and response decoding so services only supply a path + payload.
final class APIClient {

    static let shared = APIClient()

    private let baseURL = URL(string: "https://api.journpath.com")!
    private let session: URLSession
    private let decoder = JSONDecoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: config)
    }

    /// The API wraps every successful response in `{ "result": ... }`.
    private struct CallableEnvelope<T: Decodable>: Decodable {
        let result: T
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
                method: "POST",
                body: body,
                requiresAuth: requiresAuth,
                requiresAppCheck: requiresAppCheck
            )
            let (data, response) = try await session.data(for: request)

            // This will throw the appropriate APIError case if the backend sends an error
            return try parse(data: data, response: response)

        } catch let error as APIError {
            throw error
        } catch is URLError {
            throw .noInternetConnection
        } catch {
            throw .unknownServerError(status: 0, message: "An unexpected error occurred: \(error.localizedDescription)")
        }
    }

    /// GETs the given path with optional query items and returns the parsed JSON response.
    @discardableResult
    func get(
        _ path: String,
        query: [String: Any] = [:],
        requiresAuth: Bool = true,
        requiresAppCheck: Bool = true
    ) async throws(APIError) -> [String: Any] {
        do {
            let request = try await makeRequest(
                path: path,
                method: "GET",
                query: query,
                requiresAuth: requiresAuth,
                requiresAppCheck: requiresAppCheck
            )
            let (data, response) = try await session.data(for: request)
            return try parse(data: data, response: response)

        } catch let error as APIError {
            throw error
        } catch is URLError {
            throw .noInternetConnection
        } catch {
            throw .unknownServerError(status: 0, message: "An unexpected error occurred: \(error.localizedDescription)")
        }
    }

    /// GETs the given path and decodes the enveloped `result` into `T`.
    /// Prefer this over the dictionary variant anywhere a Codable model exists.
    func get<T: Decodable>(
        _ path: String,
        query: [String: Any] = [:],
        as type: T.Type,
        requiresAuth: Bool = true,
        requiresAppCheck: Bool = true
    ) async throws(APIError) -> T {
        do {
            let request = try await makeRequest(
                path: path,
                method: "GET",
                query: query,
                requiresAuth: requiresAuth,
                requiresAppCheck: requiresAppCheck
            )
            let (data, response) = try await session.data(for: request)

            // Reuse the shared status/error handling, then decode the body.
            try validate(data: data, response: response)

            do {
                return try decoder.decode(CallableEnvelope<T>.self, from: data).result
            } catch {
                #if DEBUG
                    print("[APIClient] decode failed for \(path): \(error)")
                #endif
                throw APIError.invalidResponse
            }

        } catch let error as APIError {
            throw error
        } catch is URLError {
            throw .noInternetConnection
        } catch {
            throw .unknownServerError(status: 0, message: "An unexpected error occurred: \(error.localizedDescription)")
        }
    }

    // MARK: - Request Building

    /// Builds a request with the Auth + App Check tokens optionally.
    /// `body` is encoded for methods that carry one; `query` becomes the query string.
    private func makeRequest(
        path: String,
        method: String,
        body: [String: Any]? = nil,
        query: [String: Any] = [:],
        requiresAuth: Bool,
        requiresAppCheck: Bool
    ) async throws -> URLRequest {

        var url = baseURL.appendingPathComponent(path)

        if !query.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw APIError.invalidResponse
            }
            // URLComponents handles percent-encoding, so spaces and accents are safe.
            components.queryItems =
                query
                .map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
                .sorted { $0.name < $1.name }  // stable order helps URLCache and logs

            guard let built = components.url else { throw APIError.invalidResponse }
            url = built
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

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

        // 3. Only methods with a body get one - a GET body is dropped by proxies.
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return request
    }

    // MARK: - Response Parsing

    /// Throws the matching APIError for any non-2xx response. Does not decode success bodies.
    private func validate(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw APIError(
                statusCode: http.statusCode,
                errorCode: json?["error"] as? String,
                message: json?["message"] as? String
            )
        }
    }

    private func parse(data: Data, response: URLResponse) throws -> [String: Any] {
        try validate(data: data, response: response)

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        return json
    }
}

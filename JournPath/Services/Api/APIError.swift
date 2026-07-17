//
//  APIError.swift
//  MyJourney
//

import Foundation

enum APIError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case serverError(status: Int, message: String?)
    case noInternetConnection

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to do this."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .serverError(let status, let message):
            return message ?? "Request failed with status \(status)."
        case .noInternetConnection:
            return "No internet connection. Please check your network and try again."
        }
    }
}

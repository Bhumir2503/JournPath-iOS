//
//  APIError.swift
//  MyJourney
//

import Foundation

enum APIError: LocalizedError, Equatable {
    // Local / Network
    case notAuthenticated
    case invalidResponse
    case noInternetConnection

    // Server errors (mapped from server error codes)
    case invalidArgument(message: String?)
    case failedPrecondition(message: String?)
    case unauthenticated(message: String?)
    case permissionDenied(message: String?)
    case notFound(message: String?)
    case alreadyExists(message: String?)
    case resourceExhausted(message: String?)
    case internalError(message: String?)
    case unavailable(message: String?)

    // Fallback for unmapped or generic errors
    case unknownServerError(status: Int, message: String?)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated, .unauthenticated:
            return "Authentication Required"
        case .invalidResponse:
            return "Invalid Response"
        case .noInternetConnection:
            return "Connection Error"
        case .invalidArgument:
            return "Invalid Request"
        case .failedPrecondition:
            return "Request Failed"
        case .permissionDenied:
            return "Permission Denied"
        case .notFound:
            return "Not Found"
        case .alreadyExists:
            return "Already Exists"
        case .resourceExhausted:
            return "Rate Limit Exceeded"
        case .internalError:
            return "Server Error"
        case .unavailable:
            return "Service Unavailable"
        case .unknownServerError:
            return "Unknown Error"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated, .unauthenticated:
            return "You must be signed in to do this. Please log in and try again."
        case .invalidResponse:
            return "The server returned an unexpected response. Please try again later."
        case .noInternetConnection:
            return "No internet connection. Please check your network and try again."
        case .invalidArgument(let message):
            return message ?? "The information provided was invalid. Please check your input."
        case .failedPrecondition(let message):
            return message ?? "The action couldn't be completed in the current state."
        case .permissionDenied(let message):
            return message ?? "You don't have permission to perform this action."
        case .notFound(let message):
            return message ?? "The requested information could not be found."
        case .alreadyExists(let message):
            return message ?? "The item you are trying to create already exists."
        case .resourceExhausted(let message):
            return message ?? "You have exceeded the allowed limit. Please try again later."
        case .internalError(let message):
            return message ?? "Something went wrong on our end. Please try again later."
        case .unavailable(let message):
            return message ?? "The service is temporarily down. Please try again later."
        case .unknownServerError(let status, let message):
            return message ?? "Request failed with status \(status). Please try again."
        }
    }

    init(statusCode: Int, errorCode: String?, message: String?) {
        guard let errorCode = errorCode else {
            self = .unknownServerError(status: statusCode, message: message)
            return
        }

        switch errorCode {
        case "invalid_argument": self = .invalidArgument(message: message)
        case "failed_precondition": self = .failedPrecondition(message: message)
        case "unauthenticated": self = .unauthenticated(message: message)
        case "permission_denied": self = .permissionDenied(message: message)
        case "not_found": self = .notFound(message: message)
        case "already_exists": self = .alreadyExists(message: message)
        case "resource_exhausted": self = .resourceExhausted(message: message)
        case "internal": self = .internalError(message: message)
        case "unavailable": self = .unavailable(message: message)
        default: self = .unknownServerError(status: statusCode, message: message)
        }
    }
}

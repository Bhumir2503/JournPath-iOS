import FirebaseAuth
import Foundation

enum AuthError: LocalizedError, Equatable {
    // Local validation
    case passwordsDoNotMatch
    case missingEmail
    case missingPassword
    case invalidEmailFormat
    case invalidPasswordFormat

    // Firebase-mapped
    case invalidEmail
    case emailAlreadyInUse
    case weakPassword
    case invalidCredential
    case userNotFound
    case userDisabled
    case missingEmailField
    case sessionExpired
    case requiresRecentLogin
    case networkError
    case tooManyRequests
    case operationNotAllowed
    case accountExistsWithDifferentCredential
    case credentialAlreadyInUse
    case invalidActionCode
    case expiredActionCode
    case internalError
    case notSignedIn
    case unknown

    var errorDescription: String? {
        switch self {
        case .passwordsDoNotMatch, .missingEmail, .missingPassword, .invalidEmailFormat, .invalidPasswordFormat, .missingEmailField:
            return "Validation Failed"
        case .networkError:
            return "Connection Error"
        case .sessionExpired, .requiresRecentLogin, .notSignedIn:
            return "Authentication Required"
        case .tooManyRequests:
            return "Rate Limit Exceeded"
        case .userDisabled:
            return "Account Disabled"
        case .accountExistsWithDifferentCredential, .credentialAlreadyInUse, .emailAlreadyInUse:
            return "Account Conflict"
        default:
            return "Authentication Failed"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .passwordsDoNotMatch: return "Passwords do not match."
        case .missingEmail: return "Email is required."
        case .missingPassword: return "Password is required."
        case .invalidEmailFormat: return "Please enter a valid email."
        case .invalidPasswordFormat: return "Password requirements are not met."
        case .invalidEmail: return "That email address doesn't look right. Please check it and try again."
        case .emailAlreadyInUse: return "An account with this email already exists. Try signing in instead."
        case .weakPassword: return "Your password does not meet the requirements."
        case .invalidCredential: return "Incorrect email or password. Please try again."
        case .userNotFound: return "No account found with that email. Please check it or sign up."
        case .userDisabled: return "This account has been disabled. Please contact support."
        case .missingEmailField: return "Please enter an email address to continue."
        case .sessionExpired: return "Your session has expired. Please sign in again."
        case .requiresRecentLogin: return "For security, please sign out and sign back in before making this change."
        case .networkError: return "No internet connection. Please check your network and try again."
        case .tooManyRequests: return "Too many attempts. Please wait a moment and try again."
        case .operationNotAllowed: return "This sign-in method isn't enabled. Please contact support."
        case .accountExistsWithDifferentCredential: return "An account already exists with this email using a different sign-in method."
        case .credentialAlreadyInUse: return "This sign-in method is already linked to a different account."
        case .invalidActionCode: return "This link is invalid or has already been used. Please request a new one."
        case .expiredActionCode: return "This link has expired. Please request a new one."
        case .internalError: return "Something went wrong on our end. Please try again."
        case .notSignedIn: return "You are not signed in. Please log out and log back in."
        case .unknown: return "Authentication failed. Please check your details and try again."
        }
    }

    init(firebaseError: Error) {
        let nsError = firebaseError as NSError
        guard nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) else {
            self = .unknown
            return
        }
        switch code {
        case .invalidEmail: self = .invalidEmail
        case .emailAlreadyInUse: self = .emailAlreadyInUse
        case .weakPassword: self = .weakPassword
        case .wrongPassword, .invalidCredential: self = .invalidCredential
        case .userNotFound: self = .userNotFound
        case .userDisabled: self = .userDisabled
        case .missingEmail: self = .missingEmailField
        case .userTokenExpired, .invalidUserToken: self = .sessionExpired
        case .requiresRecentLogin: self = .requiresRecentLogin
        case .networkError: self = .networkError
        case .tooManyRequests: self = .tooManyRequests
        case .operationNotAllowed: self = .operationNotAllowed
        case .accountExistsWithDifferentCredential: self = .accountExistsWithDifferentCredential
        case .credentialAlreadyInUse: self = .credentialAlreadyInUse
        case .invalidActionCode: self = .invalidActionCode
        case .expiredActionCode: self = .expiredActionCode
        case .internalError: self = .internalError
        default: self = .unknown
        }
    }
}

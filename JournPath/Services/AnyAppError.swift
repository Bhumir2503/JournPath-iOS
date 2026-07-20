import Foundation

struct AnyAppError: LocalizedError {
    private let error: LocalizedError

    init(_ error: LocalizedError) {
        self.error = error
    }

    var errorDescription: String? {
        error.errorDescription
    }

    var recoverySuggestion: String? {
        error.recoverySuggestion
    }
}

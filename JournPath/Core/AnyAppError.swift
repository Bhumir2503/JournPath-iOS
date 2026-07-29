import Foundation

struct AnyAppError: LocalizedError {
    private struct CustomStringError: LocalizedError {
        let errorDescription: String?
        let recoverySuggestion: String?
    }

    private let error: LocalizedError

    init(_ error: LocalizedError) {
        self.error = error
    }

    init(_ description: String, _ recovery: String) {
        self.error = CustomStringError(errorDescription: description, recoverySuggestion: recovery)
    }

    var errorDescription: String? {
        error.errorDescription
    }

    var recoverySuggestion: String? {
        error.recoverySuggestion
    }
}

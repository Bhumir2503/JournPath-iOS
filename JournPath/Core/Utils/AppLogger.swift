/// A centralized logging system using Apple's native OSLog framework.
import Foundation
@_exported import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "JournPath"
    static let prefix = "[AppLogger] "

    // Categories
    static let database = Logger(subsystem: subsystem, category: "Database")
    static let viewModels = Logger(subsystem: subsystem, category: "ViewModels")
    static let auth = Logger(subsystem: subsystem, category: "Authentication")
    static let routing = Logger(subsystem: subsystem, category: "Routing")
    static let managers = Logger(subsystem: subsystem, category: "Managers")

    // Main 
    static let view = Logger(subsystem: subsystem, category: "View")
    static let store = Logger(subsystem: subsystem, category: "Store")
    static let services = Logger(subsystem: subsystem, category: "Services")
}

// MARK: - Prefix Helper
extension Logger {
    /// Logs a debug message with the custom prefix.
    func debug(_ message: String) {
        self.debug("\(AppLogger.prefix)\(message, privacy: .public)")
    }

    /// Logs an info message with the custom prefix.
    func info(_ message: String) {
        self.info("\(AppLogger.prefix)\(message, privacy: .public)")
    }

    /// Logs an error message with the custom prefix.
    func error(_ message: String) {
        self.error("\(AppLogger.prefix)\(message, privacy: .public)")
    }
}

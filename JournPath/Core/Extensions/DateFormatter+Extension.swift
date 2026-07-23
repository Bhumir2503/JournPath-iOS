import Foundation

extension DateFormatter {
    /// Format: "yyyy-MM-dd"
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Format: "MMM d"
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    /// Format: "MMM d, yyyy"
    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    /// Format: "d"
    static let dayOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    /// Format: "MMMM yyyy"
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

}

extension DateFormatter {
    private static func tripFormatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")!
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }

    static let tripDay = tripFormatter("MMMd")  // "Oct 12"
    static let tripDayYear = tripFormatter("MMMdyyyy")  // "Oct 12, 2026"
    static let tripWeekday = tripFormatter("EEEMMMd")  // "Mon, Oct 12"
    static let tripFormatterDayOnly = tripFormatter("d")  // "18"
}

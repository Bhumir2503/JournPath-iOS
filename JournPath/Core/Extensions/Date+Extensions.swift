import SwiftUI

extension Date {

    /// Converts the date to a "yyyy-MM-dd" string format.
    var asYYYYMMDD: String {
        DateFormatter.yyyyMMdd.string(from: self)
    }

    /// Returns a contextual display string (e.g., "Oct 12" if current year, "Oct 12, 2023" if not).
    func displayString(showYear: Bool = false) -> String {
        let isCurrentYear = Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
        if showYear || !isCurrentYear {
            return self.formatted(.dateTime.month(.abbreviated).day().year())
        } else {
            return self.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    /// Attempts to parse a Date from a string formatted like "Oct 12" or "Oct 12, 2023".
    init?(displayString string: String) {
        // First try parsing with the year included
        if let parsedDate = try? Date(string, strategy: .dateTime.month(.abbreviated).day().year()) {
            self = parsedDate
            return
        }

        // If that fails, try parsing without the year and add the current year
        if let parsedDate = try? Date(string, strategy: .dateTime.month(.abbreviated).day()) {
            var comps = Calendar.current.dateComponents([.month, .day], from: parsedDate)
            comps.year = Calendar.current.component(.year, from: Date())
            if let finalDate = Calendar.current.date(from: comps) {
                self = finalDate
                return
            }
        }

        return nil
    }

    var deviceLocalFromUTCMidnight: Date {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let components = utcCalendar.dateComponents([.year, .month, .day], from: self)

        return Calendar.current.date(from: components) ?? self
    }

    var displayStringUTC: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone(identifier: "UTC")!
        return formatter.string(from: self)
    }

    func isSameUTCDay(as other: Date) -> Bool {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        return utcCalendar.isDate(self, inSameDayAs: other)
    }
}

extension Date {
    /// Re-anchors this date's displayed wall-clock components (the numbers a user
    /// saw on screen, e.g. "10:00 AM") into a different timezone, producing the
    /// correct absolute instant for that intended local time.
    ///
    /// Example: DatePicker shows "10:00 AM" while device is in America/New_York.
    /// Calling this with destinationTimeZone = Asia/Tokyo returns the Date that
    /// is actually 10:00 AM in Tokyo — not 10:00 AM EST reinterpreted as UTC math.
    func reanchored(from deviceTimeZone: TimeZone = .current, to destinationTimeZone: TimeZone) -> Date {
        var deviceCalendar = Calendar.current
        deviceCalendar.timeZone = deviceTimeZone

        let components = deviceCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: self
        )

        var destinationCalendar = Calendar.current
        destinationCalendar.timeZone = destinationTimeZone

        return destinationCalendar.date(from: components) ?? self
    }
}

extension Calendar {
    /// The one calendar allowed to touch trip dates.
    static let tripDates: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// A calendar pinned to an arbitrary zone (for activity day math).
    static func pinned(to tz: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal
    }
}

extension Date {
    /// Picker → Firestore: the day the user tapped, pinned to midnight UTC.
    func toTripDate(from pickerCalendar: Calendar = .current) -> Date {
        let comps = pickerCalendar.dateComponents([.year, .month, .day], from: self)
        return Calendar.tripDates.date(from: comps)!
    }

    /// Firestore → Picker: a UTC-midnight timestamp as the same day, locally.
    func toPickerDate(in pickerCalendar: Calendar = .current) -> Date {
        let comps = Calendar.tripDates.dateComponents([.year, .month, .day], from: self)
        return pickerCalendar.date(from: comps)!
    }

    var utcMidnight: Date {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return Calendar.tripDates.date(from: comps)!
    }

    var iso8601: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")!
        return f.string(from: self)  // "2026-10-12T00:00:00Z"
    }
}

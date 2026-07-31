//
//  Trip.swift
//  MyJourney
//

import FirebaseAuth
import FirebaseFirestore
import SwiftUI

enum TripTier: Int, Codable {
    case free = 0
    case premium = 1
}

struct Trip: Identifiable, Codable, Hashable {
    @DocumentID var id: String?

    // Access Control
    var inviteToken: String

    // Basic Info
    var name: String
    var coverImage: CoverImage

    // Timestamps
    var startDate: Date
    var endDate: Date

    // MetaData
    var createdAt: Date
    var updatedAt: Date?

    // Premium Flag
    var tier: TripTier

    var dynamicTextColor: Color { coverImage.textColor }
}

extension Trip {
    /// "Oct 12 – 18, 2026" / "Oct 28 – Nov 3, 2026" / "Dec 30, 2026 – Jan 2, 2027"
    var dateRangeText: String {
        let cal = Calendar.tripDates
        let s = cal.dateComponents([.year, .month, .day], from: startDate)
        let e = cal.dateComponents([.year, .month, .day], from: endDate)

        if s.year == e.year && s.month == e.month && s.day == e.day {
            return DateFormatter.tripDayYear.string(from: startDate)
        }
        if s.year == e.year && s.month == e.month {
            // Same month: collapse to "Oct 12 – 18, 2026"
            let day = DateFormatter.tripFormatterDayOnly.string(from: endDate)
            return "\(DateFormatter.tripDay.string(from: startDate)) – \(day), \(s.year!)"
        }
        if s.year == e.year {
            return "\(DateFormatter.tripDay.string(from: startDate)) – "
                + "\(DateFormatter.tripDay.string(from: endDate)), \(s.year!)"
        }
        return "\(DateFormatter.tripDayYear.string(from: startDate)) – "
            + "\(DateFormatter.tripDayYear.string(from: endDate))"
    }

    var nightCount: Int {
        Calendar.tripDates.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    var dayCount: Int { nightCount + 1 }
}

extension Trip {
    var dateRangeTextViaInterval: String {
        let f = DateIntervalFormatter()
        f.timeZone = TimeZone(identifier: "UTC")!
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: startDate, to: endDate)
    }
}

import Combine
import Foundation
import UIKit

enum DaySelectionState {
    case unselected
    case start(isSameDay: Bool)
    case end
    case between
    case outOfRange
}

class DatePickerVM: ObservableObject {
    @Published var selectedStartDate: Date?
    @Published var selectedEndDate: Date?

    let calendar: Calendar

    /// Visible range — full months, so the month containing the earliest
    /// selectable day is shown in its entirety.
    let minDate: Date
    let maxDate: Date

    /// Selectable range — start-of-day normalized bounds.
    let selectableRange: ClosedRange<Date>

    /// Start of today, used to enforce the end-date rule.
    let today: Date

    /// When true (no explicit dateRange), the end date must be today or later.
    let requiresEndOnOrAfterToday: Bool

    /// Trips are capped at 120 days.
    let maxRangeInDays = 120

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    init(initialStartDate: Date? = nil, initialEndDate: Date? = nil, dateRange: ClosedRange<Date>? = nil) {
        var cal = Calendar.current
        cal.locale = Locale.current
        self.calendar = cal

        let today = cal.startOfDay(for: Date())
        self.today = today

        let lowerBound: Date
        let upperBound: Date

        if let range = dateRange {
            // An explicit range (e.g. the parent trip's dates) is the hard
            // boundary — only days inside it are selectable, nothing else.
            lowerBound = cal.startOfDay(for: range.lowerBound)
            upperBound = cal.startOfDay(for: range.upperBound)
            self.requiresEndOnOrAfterToday = false
        } else {
            // Start dates can go up to 3 months into the past — or further
            // back if an existing selection starts earlier than that.
            let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: today) ?? today
            if let start = initialStartDate {
                lowerBound = min(cal.startOfDay(for: start), threeMonthsAgo)
            } else {
                lowerBound = threeMonthsAgo
            }

            // Max selectable date is 24 months from today.
            upperBound = cal.startOfDay(
                for: cal.date(byAdding: .month, value: 24, to: today) ?? today
            )
            self.requiresEndOnOrAfterToday = true
        }

        self.selectableRange = lowerBound...max(lowerBound, upperBound)

        // Show the full month at both ends, but days before lowerBound
        // (or after upperBound) render as out-of-range and can't be tapped.
        let firstOfLowerMonth =
            cal.date(
                from: cal.dateComponents([.year, .month], from: lowerBound)
            ) ?? lowerBound

        let firstOfUpperMonth =
            cal.date(
                from: cal.dateComponents([.year, .month], from: upperBound)
            ) ?? upperBound
        let endOfUpperMonth = cal.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfUpperMonth) ?? upperBound

        self.minDate = firstOfLowerMonth
        self.maxDate = endOfUpperMonth

        self.selectedStartDate = initialStartDate
        if let start = initialStartDate, let end = initialEndDate, cal.isDate(start, inSameDayAs: end) {
            self.selectedEndDate = nil
        } else {
            self.selectedEndDate = initialEndDate
        }
    }

    func handleDaySelection(_ date: Date) {
        let day = calendar.startOfDay(for: date)

        // Ignore taps outside the selectable range entirely.
        guard selectableRange.contains(day) else { return }

        if let start = selectedStartDate, selectedEndDate == nil {
            let startDay = calendar.startOfDay(for: start)

            // Ignore taps beyond the 120-day cap — those days are shown
            // as out-of-range, so tapping them does nothing.
            if let diff = calendar.dateComponents([.day], from: startDay, to: day).day,
                abs(diff) > maxRangeInDays
            {
                return
            }

            // The end of the range must be today or later. This covers both
            // directions: a tap before the start makes the old start the end,
            // and since day >= today implies old start > today, that's valid.
            if requiresEndOnOrAfterToday && day < today {
                return
            }

            if day < startDay {
                selectedEndDate = start
                selectedStartDate = date
            } else {
                selectedEndDate = date
            }
        } else {
            selectedStartDate = date
            selectedEndDate = nil
        }
        triggerHaptic()
    }

    /// The selection is submittable when a valid range exists. A lone start
    /// date counts as a single-day trip, which must not be in the past.
    var canSubmit: Bool {
        guard let start = selectedStartDate else { return false }
        if selectedEndDate != nil { return true }
        if requiresEndOnOrAfterToday {
            return calendar.startOfDay(for: start) >= today
        }
        return true
    }

    private func triggerHaptic() {
        haptic.prepare()
        haptic.impactOccurred()
    }

    func resetSelection() {
        selectedStartDate = nil
        selectedEndDate = nil
    }

    func state(for dayDate: Date) -> DaySelectionState {
        let day = calendar.startOfDay(for: dayDate)

        guard selectableRange.contains(day) else { return .outOfRange }

        // While picking an end date, gray out days that can't be a valid end:
        // days beyond the 120-day cap, and — when the rule applies — days
        // before today (the end date must be today or later).
        if let start = selectedStartDate, selectedEndDate == nil {
            let startDay = calendar.startOfDay(for: start)
            if day != startDay {
                if let diff = calendar.dateComponents([.day], from: startDay, to: day).day,
                    abs(diff) > maxRangeInDays
                {
                    return .outOfRange
                }
                if requiresEndOnOrAfterToday && day < today {
                    return .outOfRange
                }
            }
        }

        guard let start = selectedStartDate else { return .unselected }
        let normStart = calendar.startOfDay(for: start)

        if let end = selectedEndDate {
            let normEnd = calendar.startOfDay(for: end)
            if day == normStart && day == normEnd { return .start(isSameDay: true) }
            if day == normStart { return .start(isSameDay: false) }
            if day == normEnd { return .end }
            if day > normStart && day < normEnd { return .between }
        } else {
            if day == normStart { return .start(isSameDay: true) }
        }

        return .unselected
    }
}

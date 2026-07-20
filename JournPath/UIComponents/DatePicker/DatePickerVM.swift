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

    let calendar: Calendar = {
        var cal = Calendar.current
        cal.locale = Locale.current
        return cal
    }()

    let minDate: Date
    let maxDate: Date
    let validDateRange: ClosedRange<Date>?
    let maxRangeInDays: Int?

    init(initialStartDate: Date? = nil, initialEndDate: Date? = nil, dateRange: ClosedRange<Date>? = nil, maxRangeInDays: Int? = 180) {
        self.selectedStartDate = initialStartDate
        
        if let start = initialStartDate, let end = initialEndDate, Calendar.current.isDate(start, inSameDayAs: end) {
            self.selectedEndDate = nil
        } else {
            self.selectedEndDate = initialEndDate
        }

        self.validDateRange = dateRange
        self.maxRangeInDays = maxRangeInDays

        if let range = dateRange {
            self.minDate = range.lowerBound
            self.maxDate = range.upperBound
        } else {
            self.minDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            self.maxDate = Calendar.current.date(byAdding: .year, value: 5, to: Date()) ?? Date()
        }
    }
    
    func handleDaySelection(_ date: Date) {
        if let validRange = validDateRange {
            let normalizedDate = Calendar.current.startOfDay(for: date)
            let normalizedLower = Calendar.current.startOfDay(for: validRange.lowerBound)
            let normalizedUpper = Calendar.current.startOfDay(for: validRange.upperBound)
            if normalizedDate < normalizedLower || normalizedDate > normalizedUpper {
                return
            }
        }

        if let start = selectedStartDate, selectedEndDate == nil {
            if let maxDays = maxRangeInDays {
                let startOfDayStart = Calendar.current.startOfDay(for: start)
                let startOfDayDate = Calendar.current.startOfDay(for: date)
                if let diff = Calendar.current.dateComponents([.day], from: startOfDayStart, to: startOfDayDate).day, abs(diff) > maxDays {
                    selectedStartDate = date
                    triggerHaptic()
                    return
                }
            }

            if date < start {
                selectedEndDate = start
                selectedStartDate = date
            } else if date > start {
                selectedEndDate = date
            } else {
                selectedEndDate = date
            }
        } else {
            selectedStartDate = date
            selectedEndDate = nil
        }
        triggerHaptic()
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func resetSelection() {
        selectedStartDate = nil
        selectedEndDate = nil
    }

    func state(for dayDate: Date) -> DaySelectionState {
        if let validRange = validDateRange {
            let normalizedDay = calendar.startOfDay(for: dayDate)
            let lower = calendar.startOfDay(for: validRange.lowerBound)
            let upper = calendar.startOfDay(for: validRange.upperBound)
            if normalizedDay < lower || normalizedDay > upper {
                return .outOfRange
            }
        }

        if let start = selectedStartDate, selectedEndDate == nil, let maxDays = maxRangeInDays {
            let startOfDayStart = calendar.startOfDay(for: start)
            let startOfDayDate = calendar.startOfDay(for: dayDate)
            if let diff = calendar.dateComponents([.day], from: startOfDayStart, to: startOfDayDate).day {
                if abs(diff) > maxDays {
                    return .outOfRange
                }
            }
        }

        guard let start = selectedStartDate else { return .unselected }
        let normDay = calendar.startOfDay(for: dayDate)
        let normStart = calendar.startOfDay(for: start)

        if let end = selectedEndDate {
            let normEnd = calendar.startOfDay(for: end)
            if normDay == normStart && normDay == normEnd { return .start(isSameDay: true) }
            if normDay == normStart { return .start(isSameDay: false) }
            if normDay == normEnd { return .end }
            if normDay > normStart && normDay < normEnd { return .between }
        } else {
            if normDay == normStart { return .start(isSameDay: true) }
        }

        return .unselected
    }
}

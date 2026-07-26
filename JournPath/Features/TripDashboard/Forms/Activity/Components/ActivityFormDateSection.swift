import SwiftUI

struct ActivityFormDateCard: View {
    let trip: Trip
    let destinationTimeZone: TimeZone

    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var allDay: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                DatePicker(
                    "Starts", selection: $startDate,
                    in: selectableRange,
                    displayedComponents: displayedComponents
                )
                .padding()

                Divider().padding(.leading, 16)

                DatePicker(
                    "Ends", selection: $endDate,
                    in: endSelectableRange,
                    displayedComponents: displayedComponents
                )
                .padding()

                Divider().padding(.leading, 16)

                Toggle("All Day", isOn: $allDay)
                    .padding()
            }
            .environment(\.timeZone, destinationTimeZone)
            .padding(.vertical, 2)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            timeZoneInfo
        }
        .onAppear { clampToTrip() }
        .onChange(of: destinationTimeZone) { clampToTrip() }
        .onChange(of: startDate) { withAnimation { validateEndDate() } }
        .onChange(of: allDay) { _, isAllDay in
            withAnimation { handleAllDayChange(isAllDay) }
        }
    }
}

// MARK: - Derived

extension ActivityFormDateCard {
    private var placeCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = destinationTimeZone
        return cal
    }

    private var displayedComponents: DatePickerComponents {
        allDay ? [.date] : [.date, .hourAndMinute]
    }

    var selectableRange: ClosedRange<Date> {
        let lower = trip.startDate.tripDay(at: 0, in: destinationTimeZone)
        let upper = trip.endDate.tripDay(at: 23, minute: 59, second: 59, in: destinationTimeZone)
        return lower...max(lower, upper)
    }

    var endSelectableRange: ClosedRange<Date> {
        let lower = max(startDate, selectableRange.lowerBound)
        return lower...max(lower, selectableRange.upperBound)
    }
}

// MARK: - Mutation

extension ActivityFormDateCard {
    private func clamp(_ date: Date) -> Date {
        min(max(date, selectableRange.lowerBound), selectableRange.upperBound)
    }

    /// Pulls stored dates back inside the trip window — covers documents saved
    /// before the trip was edited, and re-entry after the zone resolves.
    private func clampToTrip() {
        let s = clamp(startDate)
        if s != startDate { startDate = s }
        let e = clamp(endDate)
        if e != endDate { endDate = e }
        validateEndDate()
    }

    private func validateEndDate() {
        guard endDate < startDate else { return }
        endDate = allDay ? startDate : clamp(startDate.addingTimeInterval(3600))
    }

    private func handleAllDayChange(_ isAllDay: Bool) {
        if isAllDay {
            startDate = clamp(placeCalendar.startOfDay(for: startDate))
            endDate = clamp(placeCalendar.startOfDay(for: endDate))
        } else {
            let start =
                placeCalendar.date(
                    bySettingHour: 10, minute: 0, second: 0, of: startDate) ?? startDate
            startDate = clamp(start)
            endDate = clamp(startDate.addingTimeInterval(3600))
        }
        validateEndDate()
    }
}

// MARK: - Chrome

extension ActivityFormDateCard {
    var timeZoneInfo: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
            Text("Times shown in \(timeZoneDisplayName)")
        }
        .padding(.horizontal, 12)
        .font(.caption)
        .foregroundStyle(Color.secondary)
    }

    var timeZoneDisplayName: String {
        destinationTimeZone.localizedName(for: .generic, locale: .current)
            ?? destinationTimeZone.identifier
    }
}

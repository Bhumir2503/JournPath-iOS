import Combine
import FirebaseAuth
import Foundation
import MapKit
import SwiftUI

@Observable
@MainActor
final class ActivityFormVM {

    // MARK: - Dependencies

    let place: PlaceResult
    let service = ItineraryService()

    // MARK: - Form State

    var startDate: Date
    var endDate: Date
    var isAllDay: Bool = true
    var note: String = "" {
        didSet {
            if note.count > 500 {
                note = String(note.prefix(500))
            }
        }
    }

    var isAddressCopied: Bool = false

    /// The trip's day range expressed as instants in the destination's zone.
    /// Recomputed in `computeSelectableRange(trip:)` before the pickers render.
    private(set) var selectableRange: ClosedRange<Date> = Date.distantPast...Date.distantFuture

    // MARK: - Timezone

    /// The timezone the activity actually happens in — resolved from the place
    /// in ItineraryBuilderVM before this form is presented.
    var destinationTimeZone: TimeZone {
        place.timeZone ?? .current
    }

    /// False when neither MapKit nor the geocoder could resolve a zone, so the
    /// form can warn that it's falling back to the device's timezone.
    var hasResolvedTimeZone: Bool {
        place.timeZone != nil
    }

    /// Calendar pinned to the destination. ALL date math in this VM uses this,
    /// never Calendar.current — startDate/endDate are true instants whose
    /// wall-clock meaning is defined by the destination's zone.
    var placeCalendar: Calendar {
        Calendar.pinned(to: destinationTimeZone)
    }

    var timeZoneDisplayName: String {
        destinationTimeZone.localizedName(for: .generic, locale: .current)
            ?? destinationTimeZone.identifier
    }

    // MARK: - Init

    init(place: PlaceResult) {
        self.place = place
        let fallback = Date()
        self.startDate = fallback
        self.endDate = fallback.addingTimeInterval(3600)
    }

    // MARK: - Date Setup

    /// Must run before `setupDates` and before the pickers evaluate their `in:` bounds.
    func computeSelectableRange(trip: Trip?) {
        guard let trip else { return }

        var startComps = Calendar.tripDates.dateComponents([.year, .month, .day], from: trip.startDate)
        startComps.hour = 0
        startComps.minute = 0

        var endComps = Calendar.tripDates.dateComponents([.year, .month, .day], from: trip.endDate)
        endComps.hour = 23
        endComps.minute = 59

        guard let lower = placeCalendar.date(from: startComps),
            let upper = placeCalendar.date(from: endComps)
        else { return }

        selectableRange = lower...max(lower, upper)
    }

    /// Defaults to 10:00 AM on the trip's first day, in the destination's zone.
    func setupDates(trip: Trip?) {
        guard let trip else {
            startDate = Date()
            endDate = startDate.addingTimeInterval(3600)
            return
        }

        var comps = Calendar.tripDates.dateComponents([.year, .month, .day], from: trip.startDate)
        comps.hour = 10
        comps.minute = 0

        let start = placeCalendar.date(from: comps) ?? Date()
        startDate = clampToRange(start)
        endDate = clampToRange(start.addingTimeInterval(3600))

        if isAllDay {
            handleAllDayChange(true)
        }
    }

    /// End can't precede start, and can't leave the trip.
    var endSelectableRange: ClosedRange<Date> {
        let lower = max(startDate, selectableRange.lowerBound)
        return lower...max(lower, selectableRange.upperBound)
    }

    private func clampToRange(_ date: Date) -> Date {
        min(max(date, selectableRange.lowerBound), selectableRange.upperBound)
    }

    // MARK: - Date Mutation

    func validateEndDate() {
        if endDate < startDate {
            endDate =
                isAllDay
                ? startDate
                : min(startDate.addingTimeInterval(3600), selectableRange.upperBound)
        }
    }

    func handleAllDayChange(_ isAllDay: Bool) {
        if isAllDay {
            startDate = clampToRange(placeCalendar.startOfDay(for: startDate))
            endDate = clampToRange(placeCalendar.startOfDay(for: endDate))
        } else {
            let start = placeCalendar.date(bySettingHour: 10, minute: 0, second: 0, of: startDate) ?? startDate
            startDate = clampToRange(start)
            endDate = clampToRange(startDate.addingTimeInterval(3600))
        }
        validateEndDate()
    }

    /// Keeps the existing clock times while moving both dates to new days.
    func updateDates(newStart: Date, newEnd: Date) {
        let cal = placeCalendar
        let startTime = cal.dateComponents([.hour, .minute], from: startDate)
        let endTime = cal.dateComponents([.hour, .minute], from: endDate)

        var s = cal.dateComponents([.year, .month, .day], from: newStart)
        s.hour = startTime.hour
        s.minute = startTime.minute

        var e = cal.dateComponents([.year, .month, .day], from: newEnd)
        e.hour = endTime.hour
        e.minute = endTime.minute

        startDate = clampToRange(cal.date(from: s) ?? newStart)
        endDate = clampToRange(cal.date(from: e) ?? newEnd)
        validateEndDate()
    }

    // MARK: - Save

    func saveActivity(tripId: String) async throws {
        guard let mapItem = place.mapItem else {
            throw ActivityFormError.missingLocation
        }

        let tzId = destinationTimeZone.identifier

        // startDate/endDate are already correct instants — the pickers were
        // pinned to destinationTimeZone, so no conversion is needed here.
        var trueStart = startDate
        var trueEnd = endDate

        if isAllDay {
            trueStart = placeCalendar.startOfDay(for: trueStart)
            trueEnd = placeCalendar.startOfDay(for: trueEnd)
        }

        let activityPayload = ActivityPayload(
            title: place.title,
            category: mapToActivityCategory(mapItem.pointOfInterestCategory),
            location: ActivityLocation(mapItem: mapItem),
            start: LocalDateTime(instant: trueStart, timeZoneId: tzId),
            end: LocalDateTime(instant: trueEnd, timeZoneId: tzId),
            allDay: isAllDay,
            participants: nil
        )

        let newActivity = ItineraryItem(
            id: nil,
            tripId: tripId,
            type: .activity,
            addedBy: Auth.auth().currentUser?.uid ?? "",
            createdAt: nil,
            cost: nil,
            currency: nil,
            bookingRef: nil,
            notes: note.isEmpty ? nil : note,
            attachments: nil,
            startTime: trueStart,
            endTime: trueEnd,
            timeZoneId: tzId,
            activity: activityPayload,
            flight: nil,
            stay: nil,
            transit: nil
        )

        try await service.saveItem(newActivity)
    }

    // MARK: - Address / Info

    func copyAddress() {
        UIPasteboard.general.string =
            place.subtitle.isEmpty
            ? "Location Coordinates Available"
            : place.subtitle

        withAnimation { isAddressCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { isAddressCopied = false }
        }
    }

    var infoItems: [(icon: String, text: String, isLink: Bool, action: (() -> Void)?)] {
        var items: [(icon: String, text: String, isLink: Bool, action: (() -> Void)?)] = []
        let addressText = place.subtitle.isEmpty ? "Location Coordinates Available" : place.subtitle

        items.append(
            (
                "mappin.and.ellipse", addressText, false,
                { [weak self] in
                    self?.copyAddress()
                }
            ))

        if let mapItem = place.mapItem {
            if let phone = mapItem.phoneNumber, !phone.isEmpty {
                items.append(
                    (
                        "phone.fill", phone, true,
                        {
                            let digits = phone.filter { $0.isNumber || $0 == "+" }
                            if let url = URL(string: "tel://\(digits)"),
                                UIApplication.shared.canOpenURL(url)
                            {
                                UIApplication.shared.open(url)
                            }
                        }
                    ))
            }

            if let websiteURL = mapItem.url {
                let clean = websiteURL.absoluteString
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                items.append(
                    (
                        "link", clean, true,
                        {
                            UIApplication.shared.open(websiteURL)
                        }
                    ))
            }
        }
        return items
    }
}

enum ActivityFormError: LocalizedError {
    case missingLocation
    var errorDescription: String? { "This place is missing location details." }
}

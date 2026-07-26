import FirebaseAuth
import Foundation
import MapKit
import SwiftUI

@Observable
@MainActor
final class ActivityFormVM {

    // MARK: - Dependencies

    let place: MKMapItem

    // Variables
    var activityTitle: String = ""

    let service = ItineraryService()

    // MARK: - Form State

    var item: ItineraryItem
    var isAddressCopied: Bool = false

    /// The trip's day range expressed as instants in the destination's zone.
    /// Computed in `computeSelectableRange(trip:)` before the pickers render.
    private(set) var selectableRange: ClosedRange<Date> = Date.distantPast...Date.distantFuture

    /// Guards against `.onAppear` re-running setup and wiping user edits when
    /// the view reappears after a push/pop.
    private var hasSetupDates = false

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

    init(place: MKMapItem) {
        self.place = place
        self.activityTitle = String(place.name?.prefix(100) ?? "")

        let fallback = Date()

        let activity = ActivityPayload(mapItem: place)

        self.item = ItineraryItem(
            tripId: "",
            type: .activity,
            allDay: true,
            startTime: fallback,
            endTime: fallback.addingTimeInterval(3600),
            activity: activity,
            createdBy: "",
        )
    }

    // MARK: - Date Setup

    func computeSelectableRange(trip: Trip?) {
        guard let trip else { return }
        let zone = destinationTimeZone
        let lower = trip.startDate.tripDay(at: 0, in: zone)
        let upper = trip.endDate.tripDay(at: 23, minute: 59, second: 59, in: zone)
        selectableRange = lower...max(lower, upper)
    }

    func setupDates(trip: Trip?) {
        guard !hasSetupDates else { return }
        hasSetupDates = true

        let start = trip?.startDate.tripDay(at: 10, in: destinationTimeZone) ?? Date()
        item.startTime = clampToRange(start)
        item.endTime = clampToRange(start.addingTimeInterval(3600))

        if item.allDay { handleAllDayChange(true) }
    }

    /// End can't precede start, and can't leave the trip.
    var endSelectableRange: ClosedRange<Date> {
        let lower = max(item.startTime, selectableRange.lowerBound)
        return lower...max(lower, selectableRange.upperBound)
    }

    private func clampToRange(_ date: Date) -> Date {
        min(max(date, selectableRange.lowerBound), selectableRange.upperBound)
    }

    // MARK: - Date Mutation

    func validateEndDate() {
        if item.endTime < item.startTime {
            item.endTime =
                item.allDay
                ? item.startTime
                : min(item.startTime.addingTimeInterval(3600), selectableRange.upperBound)
        }
    }

    func handleAllDayChange(_ isAllDay: Bool) {
        if isAllDay {
            item.startTime = clampToRange(placeCalendar.startOfDay(for: item.startTime))
            item.endTime = clampToRange(placeCalendar.startOfDay(for: item.endTime))
        } else {
            let start =
                placeCalendar.date(
                    bySettingHour: 10, minute: 0, second: 0, of: item.startTime) ?? item.startTime
            item.startTime = clampToRange(start)
            item.endTime = clampToRange(item.startTime.addingTimeInterval(3600))
        }
        validateEndDate()
    }

    /// Keeps the existing clock times while moving both dates to new days.
    func updateDates(newStart: Date, newEnd: Date) {
        let cal = placeCalendar
        let startTime = cal.dateComponents([.hour, .minute], from: item.startTime)
        let endTime = cal.dateComponents([.hour, .minute], from: item.endTime)

        var s = cal.dateComponents([.year, .month, .day], from: newStart)
        s.hour = startTime.hour
        s.minute = startTime.minute

        var e = cal.dateComponents([.year, .month, .day], from: newEnd)
        e.hour = endTime.hour
        e.minute = endTime.minute

        item.startTime = clampToRange(cal.date(from: s) ?? newStart)
        item.endTime = clampToRange(cal.date(from: e) ?? newEnd)
        validateEndDate()
    }

    // MARK: - Save

    func saveActivity(tripId: String) async throws {
        item.prepareActivityForSave(
            tripId: tripId,
            userId: Auth.auth().currentUser?.uid ?? "",
            timeZone: destinationTimeZone,
            placeCalendar: placeCalendar,
            placeTitle: place.name ?? "Unknown",
            mapItem: place
        )

        try await service.saveItem(item)
    }

    // MARK: - Address / Info

    func copyAddress() {
        UIPasteboard.general.string = place.address?.fullAddress ?? "Unknown Address"

        withAnimation { isAddressCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { isAddressCopied = false }
        }
    }
}

enum ActivityFormError: LocalizedError {
    case missingLocation
    var errorDescription: String? { "This place is missing location details." }
}

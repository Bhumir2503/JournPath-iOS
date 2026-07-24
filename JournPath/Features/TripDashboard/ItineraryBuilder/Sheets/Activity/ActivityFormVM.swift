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

    var item: ItineraryItem
    var isAddressCopied: Bool = false

    var costInfo = CostInfo()

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

    init(place: PlaceResult) {
        self.place = place
        let fallback = Date()

        let mapItem = place.mapItem
        let location = mapItem != nil ? ActivityLocation(mapItem: mapItem!) : ActivityLocation(name: place.title, address: place.subtitle)

        self.item = ItineraryItem(
            tripId: "",
            type: .activity,
            allDay: true,
            startTime: fallback,
            endTime: fallback.addingTimeInterval(3600),
            activity: ActivityPayload(
                title: "",
                category: mapItem != nil ? mapToActivityCategory(mapItem!.pointOfInterestCategory) : nil,
                location: location
            ),
            createdBy: "",
        )
    }

    // MARK: - Date Setup

    /// Must run before `setupDates` and before the pickers evaluate their `in:` bounds.
    func computeSelectableRange(trip: Trip?) {
        guard let trip else { return }

        var startComps = Calendar.tripDates.dateComponents(
            [.year, .month, .day], from: trip.startDate)
        startComps.hour = 0
        startComps.minute = 0

        var endComps = Calendar.tripDates.dateComponents(
            [.year, .month, .day], from: trip.endDate)
        endComps.hour = 23
        endComps.minute = 59

        guard let lower = placeCalendar.date(from: startComps),
            let upper = placeCalendar.date(from: endComps)
        else { return }

        selectableRange = lower...max(lower, upper)
    }

    /// Defaults to 10:00 AM on the trip's first day, in the destination's zone.
    /// Runs once — re-entry is a no-op so user edits survive view reappearance.
    func setupDates(trip: Trip?) {
        guard !hasSetupDates else { return }
        hasSetupDates = true

        guard let trip else {
            item.startTime = Date()
            item.endTime = item.startTime.addingTimeInterval(3600)
            return
        }

        if let savedCurrency = UserDefaults.standard.string(forKey: "currencyCode_\(trip.id!)") {
            costInfo.currencyCode = savedCurrency
        }

        var comps = Calendar.tripDates.dateComponents([.year, .month, .day], from: trip.startDate)
        comps.hour = 10
        comps.minute = 0

        let start = placeCalendar.date(from: comps) ?? Date()
        item.startTime = clampToRange(start)
        item.endTime = clampToRange(start.addingTimeInterval(3600))

        if item.allDay {
            handleAllDayChange(true)
        }
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
        guard let mapItem = place.mapItem else {
            throw ActivityFormError.missingLocation
        }

        item.prepareActivityForSave(
            tripId: tripId,
            userId: Auth.auth().currentUser?.uid ?? "",
            timeZone: destinationTimeZone,
            placeCalendar: placeCalendar,
            placeTitle: place.title,
            mapItem: mapItem
        )

        try await service.saveItem(item, costInfo: costInfo)
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
        let addressText =
            place.subtitle.isEmpty
            ? "Location Coordinates Available"
            : place.subtitle

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

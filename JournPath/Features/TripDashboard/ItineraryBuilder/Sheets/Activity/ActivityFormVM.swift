import Combine
import FirebaseAuth
import Foundation
import MapKit
import SwiftUI

@Observable
@MainActor
final class ActivityFormVM {
    let place: PlaceResult
    let service = ItineraryService()

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

    init(place: PlaceResult) {
        self.place = place
        let fallbackStart = Date()
        self.startDate = fallbackStart
        self.endDate = fallbackStart.addingTimeInterval(3600)
    }

    func setupDates(trip: Trip?) {
        let baseDate = trip?.startDate.deviceLocalFromUTCMidnight ?? Date()
        let fallbackStart = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: baseDate) ?? baseDate
        self.startDate = fallbackStart
        self.endDate = fallbackStart.addingTimeInterval(3600)
    }

    func validDateRange(trip: Trip?) -> ClosedRange<Date> {
        let start = trip?.startDate.deviceLocalFromUTCMidnight ?? Date.distantPast
        let end = trip?.endDate.deviceLocalFromUTCMidnight ?? Date.distantFuture
        return start...max(start, end)
    }

    /// The timezone the activity actually happens in — derived from the
    /// selected place, not the device's current location. Falls back to
    /// the device timezone only if MapKit couldn't resolve one (e.g. the
    /// place was never resolved to a full MKMapItem).
    var destinationTimeZone: TimeZone {
        place.mapItem?.timeZone ?? TimeZone.current
    }

    func validateEndDate() {
        if endDate < startDate {
            endDate = startDate.addingTimeInterval(3600)
        }
    }

    func copyAddress() {
        let addressText = !place.subtitle.isEmpty ? place.subtitle : "Location Coordinates Available"
        UIPasteboard.general.string = addressText
        withAnimation {
            isAddressCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                self.isAddressCopied = false
            }
        }
    }

    var infoItems: [(icon: String, text: String, isLink: Bool, action: (() -> Void)?)] {
        var items: [(icon: String, text: String, isLink: Bool, action: (() -> Void)?)] = []
        let addressText = !place.subtitle.isEmpty ? place.subtitle : "Location Coordinates Available"

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
                            if let url = URL(string: "tel://\(digits)"), UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            }
                        }
                    ))
            }
            if let websiteURL = mapItem.url {
                let cleanURL = websiteURL.absoluteString
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                items.append(
                    (
                        "link", cleanURL, true,
                        {
                            UIApplication.shared.open(websiteURL)
                        }
                    ))
            }
        }
        return items
    }

    func saveActivity(tripId: String) async throws {
        let location = ActivityLocation(
            mapItem: place.mapItem!
        )

        // Anchor both start and end to the destination's own timezone,
        // not the device's current timezone.
        let tzId = destinationTimeZone.identifier
        // change date to timezone so june 22, 2026 at 3:00 pm est becomes june 22, 2026 at 3;00 pm Asia/Tokyo
        let trueStart = startDate.reanchored(to: destinationTimeZone)
        let trueEnd = endDate.reanchored(to: destinationTimeZone)

        let start = LocalDateTime(instant: trueStart, timeZoneId: tzId)
        let end = LocalDateTime(instant: trueEnd, timeZoneId: tzId)
        print("Step 1")

        let mappedCategory = mapToActivityCategory(place.mapItem?.pointOfInterestCategory)

        let activityPayload = ActivityPayload(
            title: place.title,
            category: mappedCategory,
            location: location,
            start: start,
            end: end,
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
        print("Step 2")
        do {
            print(newActivity.tripId)
            try await service.saveItem(newActivity)
        } catch {
            print("Error saving activity: \(error)")
        }
        print("Step 3")
    }

    func updateDates(newStart: Date, newEnd: Date) {
        let startComps = Calendar.current.dateComponents([.hour, .minute], from: self.startDate)
        let endComps = Calendar.current.dateComponents([.hour, .minute], from: self.endDate)

        var newStartComps = Calendar.current.dateComponents([.year, .month, .day], from: newStart)
        newStartComps.hour = startComps.hour
        newStartComps.minute = startComps.minute

        var newEndComps = Calendar.current.dateComponents([.year, .month, .day], from: newEnd)
        newEndComps.hour = endComps.hour
        newEndComps.minute = endComps.minute

        self.startDate = Calendar.current.date(from: newStartComps) ?? newStart
        self.endDate = Calendar.current.date(from: newEndComps) ?? newEnd
        validateEndDate()
    }
}

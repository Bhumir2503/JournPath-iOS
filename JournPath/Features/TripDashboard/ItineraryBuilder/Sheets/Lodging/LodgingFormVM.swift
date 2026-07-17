import Combine
import FirebaseAuth
import Foundation
import MapKit
import SwiftUI

@Observable
@MainActor
final class LodgingFormVM {
    let place: PlaceResult
    let service = ItineraryService()
    


    var checkinDate: Date
    var checkoutDate: Date
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
        self.checkinDate = fallbackStart
        self.checkoutDate = fallbackStart.addingTimeInterval(86400)
    }

    func setupDates(trip: Trip?) {
        let baseDate = trip?.startDate.deviceLocalFromUTCMidnight ?? Date()
        let fallbackStart = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: baseDate) ?? baseDate
        let fallbackEnd = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: fallbackStart.addingTimeInterval(86400)) ?? fallbackStart.addingTimeInterval(86400)

        self.checkinDate = fallbackStart
        self.checkoutDate = fallbackEnd
    }

    func validDateRange(trip: Trip?) -> ClosedRange<Date> {
        let start = trip?.startDate.deviceLocalFromUTCMidnight ?? Date.distantPast
        let end = trip?.endDate.deviceLocalFromUTCMidnight ?? Date.distantFuture
        return start...max(start, end)
    }

    var destinationTimeZone: TimeZone {
        place.mapItem?.timeZone ?? TimeZone.current
    }

    func validateCheckoutDate() {
        if checkoutDate < checkinDate {
            checkoutDate = checkinDate.addingTimeInterval(86400)
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

    func saveStay(tripId: String) async throws {
        let tzId = destinationTimeZone.identifier
        
        let trueCheckin = checkinDate.reanchored(to: destinationTimeZone)
        let trueCheckout = checkoutDate.reanchored(to: destinationTimeZone)

        let checkin = LocalDateTime(instant: trueCheckin, timeZoneId: tzId)
        let checkout = LocalDateTime(instant: trueCheckout, timeZoneId: tzId)

        let addressText = place.mapItem?.address?.fullAddress ?? (!place.subtitle.isEmpty ? place.subtitle : "")

        let stayPayload = StayPayload(
            lodgingName: place.title,
            address: addressText,
            roomType: nil,
            checkin: checkin,
            checkout: checkout,
            guests: nil,
            roomNumbers: nil
        )

        let newStay = ItineraryItem(
            id: nil,
            tripId: tripId,
            type: .lodging,
            addedBy: Auth.auth().currentUser?.uid ?? "",
            createdAt: nil,
            cost: nil,
            currency: nil,
            bookingRef: nil,
            notes: note.isEmpty ? nil : note,
            attachments: nil,
            startTime: trueCheckin,
            endTime: trueCheckout,
            timeZoneId: tzId,
            activity: nil,
            flight: nil,
            stay: stayPayload,
            transit: nil
        )

        do {
            try await service.saveItem(newStay)
        } catch {
            print("Error saving stay: \(error)")
            throw error
        }
    }

    func updateDates(newStart: Date, newEnd: Date) {
        let startComps = Calendar.current.dateComponents([.hour, .minute], from: self.checkinDate)
        let endComps = Calendar.current.dateComponents([.hour, .minute], from: self.checkoutDate)

        var newStartComps = Calendar.current.dateComponents([.year, .month, .day], from: newStart)
        newStartComps.hour = startComps.hour
        newStartComps.minute = startComps.minute

        var newEndComps = Calendar.current.dateComponents([.year, .month, .day], from: newEnd)
        newEndComps.hour = endComps.hour
        newEndComps.minute = endComps.minute

        self.checkinDate = Calendar.current.date(from: newStartComps) ?? newStart
        self.checkoutDate = Calendar.current.date(from: newEndComps) ?? newEnd
        validateCheckoutDate()
    }
}

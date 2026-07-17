import CoreLocation
import Foundation
import SwiftUI

struct TripMapAnnotation: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let iconName: String
    let color: Color
    let item: ItineraryItem

    static func == (lhs: TripMapAnnotation, rhs: TripMapAnnotation) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
final class TripMapVM {
    func annotations(for items: [ItineraryItem]) -> [TripMapAnnotation] {
        var annotations: [TripMapAnnotation] = []
        for item in items {
            let id = item.id ?? UUID().uuidString
            switch item.type {
            case .activity:
                if let activity = item.activity, let coords = activity.location.coords {
                    let iconName = activity.category?.icon ?? "mappin"
                    let color = activity.category?.color ?? .red

                    annotations.append(
                        TripMapAnnotation(
                            id: id,
                            coordinate: coords.coordinate,
                            title: activity.title,
                            iconName: iconName,
                            color: color,
                            item: item
                        ))
                }
            case .flight:
                if let flight = item.flight {
                    if let originCoords = flight.origin.coords {
                        annotations.append(
                            TripMapAnnotation(
                                id: "\(id)-origin",
                                coordinate: originCoords.coordinate,
                                title: "\(flight.origin.iata) Departure",
                                iconName: "airplane",
                                color: .blue,
                                item: item
                            ))
                    }
                    if let destCoords = flight.destination.coords {
                        annotations.append(
                            TripMapAnnotation(
                                id: "\(id)-dest",
                                coordinate: destCoords.coordinate,
                                title: "\(flight.destination.iata) Arrival",
                                iconName: "airplane",
                                color: .blue,
                                item: item
                            ))
                    }
                }
            case .transit:
                if let transit = item.transit {
                    if let depCoords = transit.departure.coords {
                        annotations.append(
                            TripMapAnnotation(
                                id: "\(id)-dep",
                                coordinate: depCoords.coordinate,
                                title: transit.departure.name,
                                iconName: transitIcon(for: transit.type),
                                color: .gray,
                                item: item
                            ))
                    }
                    if let arrCoords = transit.arrival.coords {
                        annotations.append(
                            TripMapAnnotation(
                                id: "\(id)-arr",
                                coordinate: arrCoords.coordinate,
                                title: transit.arrival.name,
                                iconName: transitIcon(for: transit.type),
                                color: .gray,
                                item: item
                            ))
                    }
                }
            case .lodging:
                break
            }
        }
        return annotations
    }

    private func transitIcon(for type: TransitType) -> String {
        switch type {
        case .plane: return "airplane"
        case .train: return "tram.fill"
        case .bus: return "bus.fill"
        case .car, .taxi, .rideshare: return "car.fill"
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        case .scooter: return "scooter"
        case .boat: return "ferry.fill"
        default: return "map.fill"
        }
    }
}

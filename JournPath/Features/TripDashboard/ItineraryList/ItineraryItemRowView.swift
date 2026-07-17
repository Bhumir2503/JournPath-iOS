import SwiftUI

struct ItineraryItemRowView: View {
   let item: ItineraryItem
   let isLast: Bool
   
   var body: some View {
       VStack(spacing: 0) {
           HStack(spacing: 16) {
               // Icon
               Image(systemName: iconName)
                   .font(.system(size: 20, weight: .semibold))
                   .foregroundColor(iconColor)
                   .frame(width: 48, height: 48)
                   .background(iconColor.opacity(0.15))
                   .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
               
               // Content
               VStack(alignment: .leading, spacing: 4) {
                   Text(titleText)
                       .font(.system(size: 16, weight: .bold))
                       .foregroundColor(.primary)
                       .lineLimit(1)
                   
                   Text(subtitleTextWithTime)
                       .font(.system(size: 14))
                       .foregroundColor(.secondary)
                       .lineLimit(1)
               }
               Spacer()
           }
           .padding(.vertical, 12)
           
           if !isLast {
               Divider()
                   .padding(.leading, 64)
           }
       }
   }
   
   // MARK: - Helpers
   
   private var subtitleTextWithTime: String {
       var parts: [String] = []
       
       switch item.type {
        case .activity:
            if let cat = item.activity?.category {
                parts.append(cat.rawValue.capitalized)
            } else if let sub = subtitleText {
                parts.append(sub)
            }
       case .flight:
           if let f = item.flight {
               parts.append("\(f.origin.iata) to \(f.destination.iata)")
           }
       case .lodging:
           parts.append("Lodging")
       case .transit:
           if let t = item.transit {
               parts.append(t.type.rawValue.capitalized)
           }
       }
              if item.type == .activity, item.activity?.allDay == true {
            parts.append("All Day")
        } else {
            parts.append(item.formattedTime(item.startTime, dateStyle: .none, timeStyle: .short))
        }
       
       return parts.joined(separator: " · ")
   }
   
   private var iconName: String {
       switch item.type {
        case .activity:
            return item.activity?.category?.icon ?? "star.fill"
       case .flight:
           return "airplane"
       case .lodging:
           return "bed.double.fill"
       case .transit:
           switch item.transit?.type {
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
   
   private var iconColor: Color {
        switch item.type {
        case .activity: return item.activity?.category?.color ?? .blue // Mockup uses blue for everything, but let's keep activity blue and others as is, or maybe everything blue if requested? Let's use blue for activity
       case .flight: return .blue
       case .lodging: return .mint
       case .transit: return .gray
       }
   }
   
   private var titleText: String {
       switch item.type {
       case .activity:
           return item.activity?.title ?? "Activity"
       case .flight:
           if let f = item.flight {
               return "\(f.airline) Flight \(f.flightNumber)"
           }
           return "Flight"
       case .lodging:
           return item.stay?.lodgingName ?? "Stay"
       case .transit:
           if let t = item.transit {
               let p = t.provider != nil ? "\(t.provider!) " : ""
               return "\(p)\(t.type.rawValue.capitalized)"
           }
           return "Transit"
       }
   }
   
   private var subtitleText: String? {
       switch item.type {
       case .activity:
           return item.activity?.location.name
       case .flight:
           if let f = item.flight {
               return "\(f.origin.iata) to \(f.destination.iata)"
           }
           return nil
       case .lodging:
           return item.stay?.address
       case .transit:
           if let t = item.transit {
               return "\(t.departure.name) → \(t.arrival.name)"
           }
           return nil
       }
   }
}

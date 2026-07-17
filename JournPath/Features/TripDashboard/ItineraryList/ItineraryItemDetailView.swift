import SwiftUI

struct ItineraryItemDetailView: View {
   let item: ItineraryItem
   @Environment(\.dismiss) private var dismiss
   
   var body: some View {
       NavigationStack {
           ScrollView {
               VStack(alignment: .leading, spacing: 24) {
                   headerSection
                   
                   timeSection
                   
                   Divider()
                   
                   detailsSection
                   
                   if let notes = item.notes, !notes.isEmpty {
                       Divider()
                       VStack(alignment: .leading, spacing: 8) {
                           Text("Notes")
                               .font(.headline)
                           Text(notes)
                               .font(.body)
                               .foregroundColor(.secondary)
                       }
                       .padding(.horizontal)
                   }
                   
                   if let ref = item.bookingRef, !ref.isEmpty {
                       Divider()
                       VStack(alignment: .leading, spacing: 8) {
                           Text("Booking Reference")
                               .font(.headline)
                           Text(ref)
                               .font(.body)
                               .foregroundColor(.primary)
                               .padding()
                               .frame(maxWidth: .infinity, alignment: .leading)
                               .background(Color(UIColor.secondarySystemBackground))
                               .cornerRadius(8)
                       }
                       .padding(.horizontal)
                   }
               }
               .padding(.vertical)
           }
           .navigationTitle("Details")
           .navigationBarTitleDisplayMode(.inline)
           .toolbar {
               ToolbarItem(placement: .navigationBarTrailing) {
                   Button("Done") { dismiss() }
                       .fontWeight(.bold)
               }
           }
       }
   }
   
   // MARK: - Header
   
   @ViewBuilder
   private var headerSection: some View {
       HStack(spacing: 16) {
           Image(systemName: iconName)
               .font(.system(size: 28))
               .foregroundColor(iconColor)
               .frame(width: 64, height: 64)
               .background(iconColor.opacity(0.15))
               .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
           
           VStack(alignment: .leading, spacing: 4) {
               Text(titleText)
                   .font(.title2)
                   .fontWeight(.bold)
               Text(subtitleText)
                   .font(.subheadline)
                   .foregroundColor(.secondary)
           }
           Spacer()
       }
       .padding(.horizontal)
   }
   
   // MARK: - Time
   
   @ViewBuilder
   private var timeSection: some View {
       HStack {
           VStack(alignment: .leading, spacing: 4) {
                Text("Start")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text(item.formattedTime(item.startTime, dateStyle: .medium, timeStyle: .short))
                    .font(.subheadline)
                    .fontWeight(.semibold)
           }
           Spacer()
           Image(systemName: "arrow.right")
               .foregroundColor(.secondary)
           Spacer()
           VStack(alignment: .trailing, spacing: 4) {
                Text("End")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text(item.formattedTime(item.endTime, dateStyle: .medium, timeStyle: .short))
                    .font(.subheadline)
                    .fontWeight(.semibold)
           }
       }
       .padding()
       .background(Color(UIColor.secondarySystemBackground))
       .cornerRadius(12)
       .padding(.horizontal)
   }
   
   // MARK: - Details
   
   @ViewBuilder
   private var detailsSection: some View {
       VStack(alignment: .leading, spacing: 16) {
           switch item.type {
           case .activity:
               if let activity = item.activity {
                   detailRow(icon: "mappin.and.ellipse", title: "Location", value: activity.location.name)
                   detailRow(icon: "map", title: "Address", value: activity.location.address)
                   if let phone = activity.location.phoneNumber {
                       detailRow(icon: "phone", title: "Phone", value: phone)
                   }
               }
           case .flight:
               if let flight = item.flight {
                   detailRow(icon: "airplane.departure", title: "Departure", value: "\(flight.origin.name) (\(flight.origin.iata))")
                   detailRow(icon: "airplane.arrival", title: "Arrival", value: "\(flight.destination.name) (\(flight.destination.iata))")
                   detailRow(icon: "number", title: "Flight", value: "\(flight.airline) \(flight.flightNumber)")
               }
           case .lodging:
               if let stay = item.stay {
                   detailRow(icon: "building", title: "Lodging", value: stay.lodgingName)
                   detailRow(icon: "map", title: "Address", value: stay.address)
                   if let room = stay.roomType {
                       detailRow(icon: "bed.double", title: "Room Type", value: room)
                   }
               }
           case .transit:
               if let transit = item.transit {
                   detailRow(icon: "arrow.up.right.circle", title: "From", value: transit.departure.name)
                   detailRow(icon: "arrow.down.right.circle", title: "To", value: transit.arrival.name)
                   if let provider = transit.provider {
                       detailRow(icon: "building.2", title: "Provider", value: provider)
                   }
               }
           }
       }
       .padding(.horizontal)
   }
   
   @ViewBuilder
   private func detailRow(icon: String, title: String, value: String) -> some View {
       HStack(alignment: .top, spacing: 12) {
           Image(systemName: icon)
               .frame(width: 24)
               .foregroundColor(.secondary)
           
           VStack(alignment: .leading, spacing: 2) {
               Text(title)
                   .font(.caption)
                   .foregroundColor(.secondary)
               Text(value)
                   .font(.body)
           }
           Spacer()
       }
   }
   
   // MARK: - Derived Properties (Shared with Row View)
   
   private var iconName: String {
       switch item.type {
       case .activity: return item.activity?.category?.icon ?? "star.fill"
       case .flight: return "airplane"
       case .lodging: return "bed.double.fill"
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
       case .activity: return item.activity?.category?.color ?? .blue
       case .flight: return .blue
       case .lodging: return .mint
       case .transit: return .gray
       }
   }
   
   private var titleText: String {
       switch item.type {
       case .activity: return item.activity?.title ?? "Activity"
       case .flight:
           if let f = item.flight { return "\(f.airline) Flight \(f.flightNumber)" }
           return "Flight"
       case .lodging: return item.stay?.lodgingName ?? "Stay"
        case .transit:
            if let t = item.transit {
                let p = t.provider != nil ? "\(t.provider!) " : ""
                return "\(p)\(t.type.rawValue.capitalized)"
            }
           return "Transit"
       }
   }
   
   private var subtitleText: String {
       switch item.type {
       case .activity: return item.activity?.category?.rawValue.capitalized ?? "Activity"
       case .flight: return "Flight"
       case .lodging: return "Lodging"
       case .transit: return item.transit?.type.rawValue.capitalized ?? "Transit"
       }
   }
}

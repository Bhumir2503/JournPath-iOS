import MapKit
import SwiftUI

struct TripActivityListView: View {
   @Environment(ItineraryManager.self) private var itineraryManager
   @State private var selectedItem: ItineraryItem?

   private var groupedActivities: [(key: Date, value: [ItineraryItem])] {
       let grouped = Dictionary(grouping: itineraryManager.items) { item -> Date in
           var calendar = Calendar.current
           if let tzId = item.timeZoneId, let timeZone = TimeZone(identifier: tzId) {
               calendar.timeZone = timeZone
           }
           
           let components = calendar.dateComponents([.year, .month, .day], from: item.startTime)
           return calendar.date(from: components) ?? item.startTime
       }
       
       return grouped.map { 
           (key: $0.key, value: $0.value.sorted(by: { $0.startTime < $1.startTime })) 
       }
       .sorted(by: { $0.key < $1.key })
   }

   var body: some View {
       VStack(alignment: .leading, spacing: 16) {
           if itineraryManager.isLoading {
               ProgressView("Loading itinerary...")
                   .frame(maxWidth: .infinity)
                   .padding(.top, 96)
           } else if itineraryManager.items.isEmpty {
               emptyState
           } else {
               ScrollView {
                   LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                       ForEach(groupedActivities, id: \.key) { group in
                           Section(header: sectionHeader(for: group.key)) {
                               VStack(spacing: 0) {
                                   ForEach(Array(group.value.enumerated()), id: \.element.id) { index, item in
                                       Button(action: {
                                           selectedItem = item
                                       }) {
                                           ItineraryItemRowView(item: item, isLast: index == group.value.count - 1)
                                               .padding(.horizontal)
                                       }
                                       .buttonStyle(.plain)
                                   }
                               }
                           }
                       }
                   }
                   .padding(.bottom, 32)
               }
           }
       }
       .sheet(item: $selectedItem) { item in
           ItineraryItemDetailView(item: item)
       }
   }

   @ViewBuilder
   private func sectionHeader(for date: Date) -> some View {
       HStack {
           Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
               .font(.title2)
               .fontWeight(.bold)
               .padding(.top, 16)
               .padding(.bottom, 8)
               .padding(.horizontal, 16)
           Spacer()
       }
   }

   @ViewBuilder
   private var emptyState: some View {
       VStack(spacing: 12) {
           Image(systemName: "calendar.badge.plus")
               .font(.system(size: 40))
               .foregroundColor(.secondary)
           Text("No activities yet")
               .font(.headline)
           Text("Tap the + button to add your first activity to this trip.")
               .font(.subheadline)
               .foregroundColor(.secondary)
               .multilineTextAlignment(.center)
       }
       .frame(maxWidth: .infinity)
       .padding(.top, 96)
   }
}

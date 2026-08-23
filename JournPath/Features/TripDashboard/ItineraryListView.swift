import SwiftUI

struct ItineraryListView: View {
    let tripId: String
    
    @State private var itineraryManager: ItineraryManager

    init(tripId: String) {
        self.tripId = tripId
        _itineraryManager = State(initialValue: ItineraryManager(tripId: tripId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Itinerary")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)

            if itineraryManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if itineraryManager.items.isEmpty {
                Text("No items in your itinerary yet.")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom)
            } else {
                VStack(spacing: 0) {
                    ForEach(itineraryManager.items) { item in
                        ItineraryItemRow(item: item)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .task {
            itineraryManager.startListening()
        }
    }
}

struct ItineraryItemRow: View {
    let item: ItineraryItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Time column
            VStack(alignment: .trailing, spacing: 4) {
                if item.allDay {
                    Text("All Day")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                } else {
                    Text(item.startTime, format: .dateTime.hour().minute())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .frame(width: 65, alignment: .trailing)
            .padding(.top, 4)

            // Timeline line
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
            }

            // Content column
            VStack(alignment: .leading, spacing: 4) {
                if let activity = item.activity {
                    Text(activity.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !activity.address.isEmpty {
                        Text(activity.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(item.type.rawValue.capitalized)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .padding(.bottom, 24)
            .padding(.top, 2)
            
            Spacer()
        }
    }
}

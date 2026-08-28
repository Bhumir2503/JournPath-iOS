import SwiftUI

struct ItineraryListView: View {
    let tripId: String

    @State private var itineraryManager: ItineraryManager
    @State private var selectedItem: ItineraryItem?

    init(tripId: String) {
        self.tripId = tripId
        _itineraryManager = State(initialValue: ItineraryManager(tripId: tripId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                        ItineraryItemRow(item: item) {
                            selectedItem = item
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .padding(.bottom, 32)
        .task {
            itineraryManager.startListening()
        }
        .sheet(item: $selectedItem) { item in
            ItineraryItemPreviewView(item: item) {
                Task {
                    guard let itemId = item.id else { return }
                    do {
                        try await ItineraryService().deleteItem(tripId: tripId, itemId: itemId)
                    } catch {
                        AppLogger.store.error("Failed to delete item: \(error)")
                    }
                }
            }
        }
    }
}

struct ItineraryItemRow: View {
    let item: ItineraryItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
                .padding(.top, 16)

                // Timeline line
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 12, height: 12)
                        .padding(.top, 18)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                }

                // Content Card
                VStack(alignment: .leading, spacing: 6) {
                    if let activity = item.activity {
                        Text(activity.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        if !activity.address.isEmpty {
                            Text(activity.address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .multilineTextAlignment(.leading)
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
                            .padding(.top, 4)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)
                .padding(.top, 4)
            }
        }
        .buttonStyle(.plain)
    }
}

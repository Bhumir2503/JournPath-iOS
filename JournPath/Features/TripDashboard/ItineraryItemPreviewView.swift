import FirebaseFirestore
import MapKit
import SwiftUI

struct ItineraryItemPreviewView: View {
    let item: ItineraryItem
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(StorageStore.self) private var storageStore
    @State private var showingDeleteConfirm = false
    @State private var expense: Expense?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let activity = item.activity {
                        let position = MapCameraPosition.region(
                            MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: activity.coords.lat, longitude: activity.coords.long),
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                        Map(initialPosition: position) {
                            Marker(
                                activity.name,
                                coordinate: CLLocationCoordinate2D(latitude: activity.coords.lat, longitude: activity.coords.long)
                            )
                        }
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        // Details
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.activity?.name ?? item.type.rawValue.capitalized)
                                .font(.title2)
                                .fontWeight(.bold)

                            if let address = item.activity?.address, !address.isEmpty {
                                Text(address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                if item.allDay {
                                    Text("All Day")
                                } else {
                                    Text("\(item.startTime, format: .dateTime.hour().minute()) - \(item.endTime, format: .dateTime.hour().minute())")
                                }
                            }
                            .font(.subheadline)
                            .padding(.top, 4)
                        }

                        if let notes = item.notes, !notes.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.headline)
                                Text(notes)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let expense = expense {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Linked Expense")
                                    .font(.headline)
                                HStack {
                                    Image(systemName: (expense.category ?? .other).icon)
                                        .foregroundStyle((expense.category ?? .other).color)
                                    Text(expense.title)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(Money.formatted(expense.amountMinor, currency: expense.currency))
                                        .fontWeight(.bold)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        let files = storageStore.files(parentType: .itineraryItem, parentId: item.id ?? "")
                        if !files.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Attached Files")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                StorageGrid(
                                    files: files,
                                    progress: { _ in nil },
                                    isSelecting: .constant(false),
                                    selectedFileIds: .constant([])
                                )
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 24)

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Text("Delete Activity")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Activity Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Activity?", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this activity and any linked expenses. This action cannot be undone.")
            }
            .task {
                if let expenseId = item.expenseId {
                    do {
                        expense = try await Firestore.firestore()
                            .collection("trips").document(item.tripId)
                            .collection("expenses").document(expenseId)
                            .getDocument(as: Expense.self)
                    } catch {
                        print("Failed to fetch expense: \(error)")
                    }
                }
            }
        }
    }
}

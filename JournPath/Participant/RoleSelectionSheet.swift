import Kingfisher
import SwiftUI

struct RoleSelectionSheet: View {
    let participant: Participant
    let assignableRoles: [ParticipantRole]

    var onCancel: () -> Void

    @State private var selectedRole: ParticipantRole
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var showCaptainAlert = false
    @State private var captaincyConfirmed = false

    @Environment(TripStore.self) private var tripManager
    private var participantService = ParticipantService()

    init(
        participant: Participant,
        assignableRoles: [ParticipantRole],
        onCancel: @escaping () -> Void
    ) {
        self.participant = participant
        self.assignableRoles = assignableRoles
        self.onCancel = onCancel
        let initialRole = assignableRoles.contains(participant.role) ? participant.role : (assignableRoles.first ?? participant.role)
        _selectedRole = State(initialValue: initialRole)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        if let photoURLString = participant.photoURL, let url = URL(string: photoURLString) {
                            KFImage(url)
                                .placeholder {
                                    Circle()
                                        .fill(Color.systemGray5)
                                        .frame(width: 50, height: 50)
                                }
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.blue.gradient)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(participant.displayName.prefix(1).uppercased())
                                        .font(.headline)
                                        .foregroundColor(.white)
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(participant.displayName)
                                .font(.headline)
                            Text("Current Role: \(participant.role.rawValue.capitalized)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Role Picker Section
                Section {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(assignableRoles, id: \.self) { role in
                            Text(role.rawValue.capitalized).tag(role as ParticipantRole)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedRole) { _, newValue in
                        print("PICKER selectedRole ->", newValue.rawValue)
                        if newValue != .captain {
                            captaincyConfirmed = false
                        }
                    }
                } header: {
                    Text("Select New Role")
                }

                // Dynamic Permissions Details (matches DeleteAccountView warnings)
                Section {
                    ForEach(permissions(for: selectedRole), id: \.text) { perm in
                        PermissionRow(icon: perm.icon, text: perm.text, color: perm.color)
                    }
                } header: {
                    Text("What they can do")
                }

                // Actions Section (utilizing AsyncIconTextButton)
                Section {
                    VStack(spacing: 16) {
                        if selectedRole == .captain && participant.role != .captain && !captaincyConfirmed {
                            Button {
                                showCaptainAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("Acknowledge Risk")
                                }
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        } else {
                            AsyncIconTextButton(
                            title: "Save Changes",
                            iconName: "checkmark.circle.fill",
                            isDisabled: selectedRole == participant.role,
                            buttonColor: .blue,
                            successColor: .green,
                            action: {
                                isSaving = true
                                errorMessage = nil
                                successMessage = nil
                                do {
                                    try await participantService.changeRole(
                                        tripId: tripManager.tripId,
                                        userId: participant.id!,
                                        role: selectedRole
                                    )
                                    withAnimation {
                                        successMessage = "Role updated successfully!"
                                    }
                                    isSaving = false
                                } catch {
                                    withAnimation {
                                        errorMessage = error.localizedDescription
                                    }
                                    isSaving = false
                                    throw error
                                }
                            },
                            closingAction: {
                                onCancel()
                            }
                        )
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else if let successMessage {
                            Text(successMessage)
                                .font(.footnote)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } footer: {
                    Text("Changes to participant roles take effect immediately across all trip dashboards.")
                }
            }
            .navigationTitle("Change Role")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDragIndicator(.visible)
            .alert("Transfer Captaincy?", isPresented: $showCaptainAlert) {
                Button("Cancel", role: .cancel) {}
                Button("I Understand", role: .destructive) {
                    withAnimation {
                        captaincyConfirmed = true
                    }
                }
            } message: {
                Text("There can only be one captain. If you save this change, you will lose your captain role and be demoted to a passenger.")
            }
        }
    }

    private func permissions(for role: ParticipantRole) -> [PermissionItem] {
        switch role {
        case .captain:
            return [
                PermissionItem(icon: "crown.fill", text: "Full trip ownership and settings control", color: .yellow),
                PermissionItem(icon: "person.badge.plus.fill", text: "Manage all co-captains, passengers, and viewers", color: .blue),
                PermissionItem(icon: "pencil.and.outline", text: "Create, edit, and delete all trip features", color: .blue),
            ]
        case .passenger:
            return [
                PermissionItem(icon: "square.and.pencil", text: "Collaborate and edit all trip content", color: .blue),
                PermissionItem(icon: "photo.on.rectangle.angled", text: "View and access all shared trip files & resources", color: .blue),
                PermissionItem(icon: "bell.fill", text: "Receive real-time notifications about updates", color: .blue),
            ]
        case .observer:
            return [
                PermissionItem(icon: "eye.fill", text: "View all trip details, itinerary, and updates", color: .blue),
                PermissionItem(icon: "doc.text", text: "Access shared media, links, and documents", color: .blue),
                PermissionItem(icon: "lock.fill", text: "Cannot make changes or edit trip details", color: .red),
            ]
        }
    }
}

struct PermissionItem {
    let icon: String
    let text: String
    let color: Color
}

struct PermissionRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(text)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

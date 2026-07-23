import FirebaseAuth
import Kingfisher
import PhotosUI
import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(UserManager.self) var session

    private let authService = AuthService()
    private let userStorage = UserStorageService()

    // UI State
    @State private var displayName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var selectedAvatarURL: String? = nil

    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    @FocusState private var isNameFocused: Bool

    // check with session store to see if updates have been made
    private var isValid: Bool {
        let newName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = !newName.isEmpty && newName != session.displayName
        let photoChanged = selectedImageData != nil || (selectedAvatarURL != nil && selectedAvatarURL != session.photoURL)
        return nameChanged || photoChanged
    }

    private func compressProfileImage(from data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxDimension: CGFloat = 800

        var targetSize = image.size
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let ratio = image.size.width / image.size.height
            if ratio > 1 {
                targetSize = CGSize(width: maxDimension, height: maxDimension / ratio)
            } else {
                targetSize = CGSize(width: maxDimension * ratio, height: maxDimension)
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // Map 1:1 to pixels
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // 0.6 is a good balance for profile avatars
        return resizedImage.jpegData(compressionQuality: 0.6) ?? data
    }

    func updateProfile() async throws {
        guard let uid = session.uid else { return }

        let newName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = newName.isEmpty ? session.displayName : newName

        // Resolve the final photo URL (upload happens client-side; the bytes are here).
        var finalPhotoURL: String? = nil
        if let selectedImageData {
            let compressedData = compressProfileImage(from: selectedImageData)
            let url = try await userStorage.uploadProfilePhoto(uid: uid, data: compressedData)
            finalPhotoURL = url.absoluteString
        } else if let selectedAvatarURL {
            finalPhotoURL = selectedAvatarURL
        }

        // Only send fields that actually changed.
        var payload: [String: Any] = [:]
        if finalName != session.displayName {
            payload["displayName"] = finalName
        }
        if let finalPhotoURL, finalPhotoURL != (session.photoURL ?? "") {
            payload["photoURL"] = finalPhotoURL
        }

        // Nothing changed — bail (your isValid guard should prevent this, but be safe).
        guard !payload.isEmpty else { return }

        try await authService.updateProfile(payload: payload)
    }

    var body: some View {
        Form {
            // Profile Picture Section
            Section {
                VStack {
                    if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                    } else if let selectedAvatarURL, let url = URL(string: selectedAvatarURL) {
                        KFImage(url)
                            .placeholder {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.gray.opacity(0.8))
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                    } else if let photoURL = session.photoURL, let url = URL(string: photoURL) {
                        KFImage(url)
                            .placeholder {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.gray.opacity(0.8))
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .foregroundColor(.gray.opacity(0.8))
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(AvatarIcons.allValues, id: \.self) { avatarURL in
                                if let url = URL(string: avatarURL) {
                                    Button {
                                        selectedAvatarURL = avatarURL
                                        selectedImageData = nil
                                        selectedPhotoItem = nil
                                    } label: {
                                        KFImage(url)
                                            .placeholder {
                                                Circle()
                                                    .fill(Color.gray.opacity(0.2))
                                            }
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle().stroke(
                                                    (selectedAvatarURL == avatarURL) || (session.photoURL == avatarURL && selectedImageData == nil && selectedAvatarURL == nil) ? Color.blue : Color.clear,
                                                    lineWidth: 3
                                                )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        Text("Change Photo")
                            .font(.footnote)
                    }
                    .padding(.top, 8)
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedImageData = data
                                selectedAvatarURL = nil
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            // Name Section
            Section {
                TextField(session.displayName, text: $displayName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .focused($isNameFocused)
                    .onAppear {
                        if displayName.isEmpty {
                            displayName = session.displayName
                        }
                    }

            } header: {
                Text("Display Name")
            } footer: {
                Text("This is how you will appear to other users across the app.")
            }

            // Submit Section
            VStack(spacing: 16) {
                AsyncIconTextButton(
                    title: "Save Changes",
                    iconName: "",
                    isDisabled: !isValid,
                    buttonColor: .blue,
                    successColor: .blue
                ) {
                    isNameFocused = false
                    errorMessage = nil
                    successMessage = nil
                    do {
                        try await updateProfile()
                        successMessage = "Your profile has been successfully updated."
                    } catch let error as LocalizedError {
                        errorMessage = error.recoverySuggestion ?? error.localizedDescription
                        throw error
                    } catch {
                        errorMessage = error.localizedDescription
                        throw error
                    }
                } closingAction: {
                    try? await Auth.auth().currentUser?.reload()
                    dismiss()
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
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: errorMessage)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: successMessage)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct StorageCard: View {
    let pendingAttachments: [PendingAttachment]

    @State private var showingPopup = false
    @State private var showingCamera = false
    @State private var showingScanner = false
    @State private var showingFileImporter = false
    @State private var showingPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        Button {
            showingPopup = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)

                Text("Add Attachments")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("PDFs, Photos, Documents")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopup) {
            VStack(spacing: 0) {
                optionRow(title: "Take Photo", icon: "camera") {
                    showingCamera = true
                }

                optionRow(title: "Photo Library", icon: "photo.on.rectangle") {
                    showingPhotosPicker = true
                }

                optionRow(title: "Scan Document", icon: "doc.text.viewfinder") {
                    showingScanner = true
                }

                optionRow(title: "Choose File", icon: "folder") {
                    showingFileImporter = true
                }
            }
            .padding(.vertical, 8)
            .presentationCompactAdaptation(.popover)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                // Handle captured image
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingScanner) {
            DocumentScannerView { images in
                // Handle scanned documents
            }
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType.item],
            allowsMultipleSelection: true
        ) { result in
            // Handle imported files
        }
        .photosPicker(
            isPresented: $showingPhotosPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newValue in
            if newValue != nil {
                // Handle selected photo
                selectedPhotoItem = nil  // Reset selection
            }
        }
    }

    private func optionRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            showingPopup = false
            // Delay action slightly to allow popover to dismiss before presenting new sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.primary)
                    .frame(width: 24)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

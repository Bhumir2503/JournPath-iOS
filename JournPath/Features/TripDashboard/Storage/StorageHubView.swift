import AVFoundation
import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main View
struct StorageHubView: View {
    let tripId: String

    @Environment(TripManager.self) private var tripManager
    @Environment(AttachmentManager.self) private var attachmentManager
    @Environment(UploadManager.self) private var uploadManager

    @State private var vm: StorageHubVM

    // MARK: - Picker States
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showScanner = false
    @State private var showFileImporter = false
    @State private var showPhotoPicker = false

    init(tripId: String) {
        self.tripId = tripId
        _vm = State(initialValue: StorageHubVM(tripId: tripId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                QuotaBar()
                mainContent
            }
            .toolbar { toolbar }
            .background(Color.systemGroupedBackground)
            .environment(vm)
            .navigationTitle("Storage Hub")
            .navigationBarTitleDisplayMode(.inline)
        }
        .overlay(alignment: .bottom) {
            let tripUploads = uploadManager.activeTasks.filter { $0.tripId == tripId }
            if !tripUploads.isEmpty {
                UploadToastOverlay(tasks: tripUploads)
            }
        }
        .alert("Error", isPresented: $vm.isShowingErrorAlert) {
            Button("OK") {}
        } message: {
            Text(vm.errorMessage)
        }
    }

    private var mainContent: some View {
        Group {
            if attachmentManager.attachments.isEmpty {
                emptyStateView
            } else {
                fileGrid
            }
        }
        .quickLookPreview($vm.previewURL)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .image, .spreadsheet, .text, .data],
            allowsMultipleSelection: true
        ) { result in
            do {
                try uploadManager.handleFileImport(tripId: tripId, result: result, currentStorage: attachmentManager.totalBytesUsed, maxStorage: vm.maxStorageBytes)
            } catch {
                vm.errorMessage = error.localizedDescription
                vm.isShowingErrorAlert = true
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItems,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, newItems in
            uploadManager.handlePhotoSelection(tripId: tripId, newItems: newItems, currentStorage: attachmentManager.totalBytesUsed, maxStorage: vm.maxStorageBytes) { error in
                vm.errorMessage = error.localizedDescription
                vm.isShowingErrorAlert = true
            }
            selectedPhotoItems = []  // Reset selection
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                do {
                    try uploadManager.handleCameraCapture(tripId: tripId, image: image, currentStorage: attachmentManager.totalBytesUsed, maxStorage: vm.maxStorageBytes)
                } catch {
                    vm.errorMessage = error.localizedDescription
                    vm.isShowingErrorAlert = true
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { images in
                do {
                    try uploadManager.processScannedDocuments(tripId: tripId, images: images, currentStorage: attachmentManager.totalBytesUsed, maxStorage: vm.maxStorageBytes)
                } catch {
                    vm.errorMessage = error.localizedDescription
                    vm.isShowingErrorAlert = true
                }
            }
            .ignoresSafeArea()
        }
    }

    private var fileGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 20) {
                    ForEach(attachmentManager.attachments) { attachment in
                        GridCell(attachment: attachment)
                    }

                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Documents", systemImage: "folder")
        } description: {
            Text("Store PDFs, docs, spreadsheets, or photos securely for your trip.")
        }
    }

    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                // PhotosPicker lives natively inside the Menu!
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Choose Photo", systemImage: "photo")
                }

                Button {
                    showCamera = true
                } label: {
                    Label("Open Camera", systemImage: "camera")
                }

                Button {
                    showScanner = true
                } label: {
                    Label("Scan Document", systemImage: "doc.text.viewfinder")
                }

                Button {
                    showFileImporter = true
                } label: {
                    Label("Upload Files", systemImage: "folder")
                }
            } label: {
                Label("Add File", systemImage: "plus")
            }
        }
    }
}

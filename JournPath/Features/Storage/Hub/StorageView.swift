import PhotosUI
import SwiftUI

struct StorageView: View {
    @Environment(TripStore.self) private var tripStore
    @Environment(StorageStore.self) private var store
    @Environment(UploadManager.self) private var uploads

    @State private var vm: StorageVM
    @State private var activeSource: FilePickerSource?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var selected: StorageFile?

    @State private var isSelecting = false
    @State private var selectedFileIds: Set<String> = []
    @State private var showingBulkDeleteConfirm = false

    // StorageView
    private var quota: StorageVM.QuotaContext {
        .init(
            usedBytes: tripStore.trip?.storageUsedBytes ?? 0,
            inFlightBytes: store.inFlightBytes,
            limitBytes: tripStore.trip?.storageQuota ?? 10 * 1024 * 1024
        )
    }

    /// Constructed here rather than in `.task` — construction is pure, and
    /// rebuilding on every reappearance would drop the resolved thumbnails.
    init(uid: String?) {
        _vm = State(initialValue: StorageVM(uid: uid))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color.systemGroupedBackground)
                .navigationTitle("Storage Hub")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .modifier(
                    FilePickers(
                        activeSource: $activeSource,
                        photoItems: $photoItems,
                        onFiles: { vm.stage($0, tripId: store.tripId, quota: quota) },
                        onPhotos: { await vm.stage(photos: $0, tripId: store.tripId, quota: quota) },
                        onImage: { vm.stage(image: $0, tripId: store.tripId, quota: quota) },
                        onScan: { vm.stage(scan: $0, tripId: store.tripId, quota: quota) },
                        onError: { _ in print("Error") }
                    )
                )
                .alert("Delete \(selectedFileIds.count) files?", isPresented: $showingBulkDeleteConfirm) {
                    Button("Delete", role: .destructive) { bulkDeleteSelected() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This action cannot be undone.")
                }
                .alert("Error", isPresented: $vm.showingError) {
                    Button("OK") {}
                } message: {
                    Text(vm.errorMessage ?? "Something went wrong.")
                }
            // .sheet(item: $selected) { file in
            //     FileDetailView(file: file)
            // }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {

            switch store.state {
            case .idle, .loading:
                Spacer()
                ProgressView()
                Spacer()

            case .failed(let error):
                Spacer()
                ContentUnavailableView {
                    Label("Couldn't load files", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                }
                Spacer()

            case .loaded where store.files.isEmpty:
                Spacer()
                ContentUnavailableView(
                    "No files yet",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Add photos or documents to your trip")
                )
                Spacer()

            case .loaded:
                ScrollView {
                    StorageGrid(
                        files: store.uploadedFiles,
                        progress: uploads.progress(for:),
                        isSelecting: $isSelecting,
                        selectedFileIds: $selectedFileIds
                    )
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    UploadTray()
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Menu {
                    ForEach(FilePickerSource.allCases) { source in
                        Button {
                            activeSource = source
                        } label: {
                            Label(source.title, systemImage: source.systemImage)
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }

        }

        ToolbarItem(placement: .navigationBarLeading) {
            if isSelecting {
                Button("Cancel") {
                    isSelecting = false
                    selectedFileIds.removeAll()
                }
            } else if !store.uploadedFiles.isEmpty {
                Button("Select") {
                    isSelecting = true
                }
            }
        }

        if isSelecting {
            ToolbarSpacer(placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button {
                    showingBulkDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .disabled(selectedFileIds.isEmpty)
            }
        } else {
            ToolbarItem(placement: .bottomBar) {
                StorageQuotaBar()
            }.sharedBackgroundVisibility(.hidden)
        }
    }

    private func bulkDeleteSelected() {
        let idsToDelete = Array(selectedFileIds)
        Task {
            do {
                try await FileService.shared.bulkDelete(tripId: store.tripId, fileIds: idsToDelete)
                isSelecting = false
                selectedFileIds.removeAll()
            } catch {
                vm.errorMessage = error.localizedDescription
                vm.showingError = true
            }
        }
    }
}

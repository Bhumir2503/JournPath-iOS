import PhotosUI
import SwiftUI

struct StorageView: View {
    @Environment(SessionStore.self) private var session
    @Environment(StorageStore.self) private var store
    @Environment(UploadManager.self) private var uploads

    @State private var vm: StorageVM
    @State private var activeSource: FilePickerSource?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var selected: StorageFile?

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
                .task { await vm.resolveThumbnails(for: store.files) }
                .onChange(of: store.files.compactMap(\.thumbnailPath).count) { _, _ in
                    Task { await vm.resolveThumbnails(for: store.files) }
                }
                .modifier(
                    FilePickers(
                        activeSource: $activeSource,
                        photoItems: $photoItems,
                        onFiles: { vm.stage($0, tripId: store.tripId) },
                        onPhotos: { await vm.stage(photos: $0, tripId: store.tripId) },
                        onImage: { vm.stage(image: $0, tripId: store.tripId) },
                        onScan: { vm.stage(scan: $0, tripId: store.tripId) },
                        onError: { _ in print("Error") }
                    )
                )
                .alert("Something went wrong", isPresented: $vm.showingError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(vm.errorMessage ?? "")
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
                } actions: {
                    Button("Retry") { store.retry() }
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
                        files: store.files,
                        currentUid: session.uid,
                        thumbnailURL: vm.thumbnailURL(for:),
                        progress: uploads.progress(for:),
                    )
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if vm.isStaging {
                ProgressView()
            } else {
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

        ToolbarItem(placement: .bottomBar) {
            StorageQuotaBar()
        }.sharedBackgroundVisibility(.hidden)
    }
}

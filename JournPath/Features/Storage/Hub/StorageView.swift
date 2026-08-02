import SwiftUI
import PhotosUI

struct StorageView: View {
    @State private var activeSource: FilePickerSource?
    @State private var photoItems: [PhotosPickerItem] = []

    @Environment(SessionStore.self) private var session
    @Environment(StorageStore.self) private var store
    
    @State private var vm: StorageVM?

    var body: some View {
        NavigationStack {
            VStack {
                StorageQuotaBar()
                    .padding()

                ContentUnavailableView(
                    "No files yet",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Add photos or documents to your trip")
                )
            }
            .toolbar { Toolbar }
            .background(Color.systemGroupedBackground)
            .navigationTitle("Storage Hub")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                self.vm = StorageVM(uid: session.uid)
                await vm?.resolveThumbnails(for: store.files)
            }
            .onChange(of: store.files) { _, files in
                Task { await vm?.resolveThumbnails(for: files) }
            }
            .fullScreenCover(item: fullScreenBinding) { source in
                    switch source {
                    case .camera:
                        CameraView { vm?.stage(image: $0, tripId: store.tripId) }
                            .ignoresSafeArea()
                    case .scanner:
                        DocumentScannerView { vm?.stage(scan: $0, tripId: store.tripId) }
                            .ignoresSafeArea()
                    default:
                        EmptyView()
                    }
                }

                .fileImporter(
                    isPresented: binding(for: .files),
                    allowedContentTypes: [.image, .pdf, .plainText],
                    allowsMultipleSelection: true
                ) { result in
                    activeSource = nil
                    if case .success(let urls) = result {
                         vm?.stage(urls, tripId: store.tripId)
                    }
                }

                .photosPicker(
                    isPresented: binding(for: .photoLibrary),
                    selection: $photoItems,
                    matching: .images
                ).onChange(of: photoItems) { _, items in
                    guard !items.isEmpty else { return }
                    let picked = items
                    photoItems = []
                    activeSource = nil
                    Task { await vm?.stage(photos: picked, tripId: store.tripId) }
                }
        }
    }
    
    private var fullScreenBinding: Binding<FilePickerSource?> {
        Binding(
            get: { activeSource?.isFullScreen == true ? activeSource : nil },
            set: { if $0 == nil { activeSource = nil } }
        )
    }

    private func binding(for source: FilePickerSource) -> Binding<Bool> {
        Binding(
            get: { activeSource == source },
            set: { if !$0 { activeSource = nil } }
        )
    }

    private var Toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
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
}

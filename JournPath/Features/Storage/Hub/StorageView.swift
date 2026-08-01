import SwiftUI
import PhotosUI

struct StorageView: View {
    @State private var activeSource: FilePickerSource?
    @State private var photoItems: [PhotosPickerItem] = []

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
            .toolbar { toolbar }
            .background(Color.systemGroupedBackground)
            .navigationTitle("Storage Hub")
            .navigationBarTitleDisplayMode(.inline)

            .fullScreenCover(item: fullScreenBinding) { source in
                    switch source {
                    case .camera:
                        CameraView { _ in print("Hello, world!") }
                            .ignoresSafeArea()
                    case .scanner:
                        DocumentScannerView { _ in print("Hello, world!")}
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
                        // vm.stage(urls, tripId: store.tripId)
                    } else if case .failure(let error) = result {
                        // vm.present(error)
                    }
                }

                .photosPicker(
                    isPresented: binding(for: .photoLibrary),
                    selection: $photoItems,
                    matching: .images
                )
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

    private var toolbar: some ToolbarContent {
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

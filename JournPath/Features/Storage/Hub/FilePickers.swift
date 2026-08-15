// Files/Attach/FilePickers.swift
import PhotosUI
import SwiftUI

/// The four ways bytes enter the app. Camera and scanner are full-screen
/// presentations; files and photo library are system modifiers driven by
/// a Bool, so one `.sheet(item:)` can't cover all four.
struct FilePickers: ViewModifier {
    @Binding var activeSource: FilePickerSource?
    @Binding var photoItems: [PhotosPickerItem]

    let onFiles: ([URL]) -> Void
    let onPhotos: ([PhotosPickerItem]) async -> Void
    let onImage: (UIImage) -> Void
    let onScan: ([UIImage]) -> Void
    let onError: (Error) -> Void

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: fullScreenBinding) { source in
                switch source {
                case .camera:
                    CameraView { image in
                        activeSource = nil
                        onImage(image)
                    }
                    .ignoresSafeArea()
                case .scanner:
                    DocumentScannerView { images in
                        activeSource = nil
                        onScan(images)
                    }
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
                switch result {
                case .success(let urls): onFiles(urls)
                case .failure(let error): onError(error)
                }
            }
            .photosPicker(
                isPresented: binding(for: .photoLibrary),
                selection: $photoItems,
                matching: .images
            )
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                let picked = items
                photoItems = []
                activeSource = nil
                Task { await onPhotos(picked) }
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
}

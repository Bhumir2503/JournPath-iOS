//
//  UnsplashImagePicker.swift
//  MyJourney
//
//  Created by Bhumir Patel on 5/5/26.
//

import PhotosUI
import SwiftUI
import Kingfisher

struct UnsplashImagePicker: View {
    var onCancel: () -> Void
    var onSubmit: (UnsplashImage) -> Void

    @StateObject private var vm: UnsplashImagePickerViewModel

    init(
        preSearchText: String,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (UnsplashImage) -> Void
    ) {
        self.onCancel = onCancel
        self.onSubmit = onSubmit
        self._vm = StateObject(
            wrappedValue: UnsplashImagePickerViewModel(preSearchText: preSearchText))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    if vm.isLoading && vm.images.isEmpty {
                        loadingView
                    } else if vm.errorMessage != nil {
                        errorView(message: vm.errorMessage!, image: vm.errorImage)
                    } else if vm.images.isEmpty && !vm.searchText.isEmpty {
                        noResultsView
                    } else if vm.images.isEmpty && vm.searchText.isEmpty {
                        initialEmptyStateView
                    } else {
                        imageGrid
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Choose Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .onAppear {
                Task {
                    await vm.searchImages(query: vm.searchText, page: 1)
                }
            }
            .searchable(
                text: $vm.searchText, placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search for Images..."
            )
            .searchPresentationToolbarBehavior(.avoidHidingContent)
        }
    }

    // MARK: - Subcomponents

    private var loadingView: some View {
        ProgressView("Searching images for \(vm.searchText)...")
    }

    private func errorView(message: String, image: String = "x.circle") -> some View {
        ContentUnavailableView(
            message,
            systemImage: image
        )
    }

    private var noResultsView: some View {
        ContentUnavailableView(
            "No images found",
            systemImage: "photo.on.rectangle.angled",
            description: Text("Try searching for something else.")
        )
    }

    private var initialEmptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("Search for an image")
                .foregroundColor(.gray)
        }
    }

    private var imageGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
                spacing: 2
            ) {
                ForEach(vm.images) { image in
                    imageCell(image: image)
                }
            }
            .padding(.horizontal, 2)

            if vm.hasMorePages && !vm.images.isEmpty {
                ProgressView()
                    .padding()
            }
        }
    }

    private func imageCell(image: UnsplashImage) -> some View {
        KFImage(URL(string: image.urls.small))
            .placeholder {
                Rectangle()
                    .fill(Color(uiColor: .systemGray5))
                    .overlay(ProgressView())
            }
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(
                minWidth: 0, maxWidth: .infinity, minHeight: 0,
                maxHeight: .infinity
            )
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                Text(image.user.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
            }
            .onTapGesture {
                onSubmit(image)
            }
            .onAppear {
                if let index = vm.images.firstIndex(where: {
                    $0.id == image.id
                }) {
                    let thresholdIndex = max(0, vm.images.count - 21)
                    if index >= thresholdIndex {
                        Task {
                            await vm.loadMore()
                        }
                    }
                }
            }
    }
}

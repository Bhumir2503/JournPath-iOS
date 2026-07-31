//
//  UnsplashImagePicker.swift
//  MyJourney
//
//  Created by Bhumir Patel on 5/5/26.
//

import Kingfisher
import SwiftUI

struct UnsplashImagePicker: View {
    var onCancel: () -> Void
    var onSubmit: (UnsplashImage) -> Void

    @StateObject private var vm: UnsplashImagePickerViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

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
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Choose Image")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel", action: onCancel)
                    }
                }
                .searchable(
                    text: $vm.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search for Images..."
                )
                .searchPresentationToolbarBehavior(.avoidHidingContent)
                .task { vm.onAppear() }
        }
    }

    // MARK: - State routing

    @ViewBuilder
    private var content: some View {
        if let message = vm.errorMessage {
            errorView(message: message, image: vm.errorImage)
        } else if vm.isLoading && vm.images.isEmpty {
            loadingView
        } else if vm.images.isEmpty {
            noResultsView
        } else {
            imageGrid
        }
    }

    // MARK: - Subcomponents

    private var loadingView: some View {
        ProgressView {
            // searchText can be empty - the view model falls back to a default term.
            Text(vm.searchText.isEmpty ? "Loading images..." : "Searching for \(vm.searchText)...")
        }
    }

    private func errorView(message: String, image: String) -> some View {
        ContentUnavailableView {
            Label(message, systemImage: image)
        } actions: {
            Button("Try Again") { vm.retry() }
        }
    }

    private var noResultsView: some View {
        ContentUnavailableView(
            "No images found",
            systemImage: "photo.on.rectangle.angled",
            description: Text("Try searching for something else.")
        )
    }

    private var imageGrid: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(vm.images) { image in
                        imageCell(image: image)
                    }
                }
                .padding(.horizontal, 2)

                footer
            }
        }
        .scrollDismissesKeyboard(.immediately)
    }

    /// Doubles as the infinite-scroll trigger. It lives in a LazyVStack, so it is
    /// only built when the user scrolls near it - and rebuilt each time it comes
    /// back into view after new rows are appended.
    @ViewBuilder
    private var footer: some View {
        if vm.hasMorePages {
            ProgressView()
                .padding(.vertical, 24)
                // Deliberately not `.task` - that would cancel the fetch as soon
                // as the spinner scrolled out of view.
                .onAppear { Task { await vm.loadMore() } }
        } else {
            Link(destination: URL(string: "https://unsplash.com/?utm_source=journpath&utm_medium=referral")!) {
                Text("Photos from Unsplash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)
        }
    }

    private func imageCell(image: UnsplashImage) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                KFImage(URL(string: image.urls.small))
                    .placeholder {
                        // Unsplash gives us the photo's average colour, so the grid
                        // fills in instantly instead of flashing grey boxes.
                        placeholderColor(image.color)
                    }
                    .fade(duration: 0.15)
                    .cacheOriginalImage()
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { onSubmit(image) }
            .overlay(alignment: .bottom) {
                attribution(for: image)
            }
            .accessibilityLabel("Photo by \(image.user.name)")
    }

    private func attribution(for image: UnsplashImage) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Scrim keeps the name legible over bright photos.
            LinearGradient(
                colors: [.black.opacity(0.55), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            attributionLabel(for: image)
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
        }
        .frame(maxHeight: 32, alignment: .bottom)
    }

    @ViewBuilder
    private func attributionLabel(for image: UnsplashImage) -> some View {
        let label = Text(image.user.name)
            .font(.caption2)
            .fontWeight(.semibold)
            .lineLimit(1)
            .foregroundStyle(.white)

        // Tapping the name opens the photographer's profile; tapping anywhere
        // else in the cell still selects the photo.
        if let url = URL(string: image.user.profile) {
            Link(destination: url) { label }
        } else {
            label
        }
    }

    /// Unsplash returns colours as "#RRGGBB".
    private func placeholderColor(_ hex: String) -> Color {
        var value: UInt64 = 0
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex

        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else {
            return Color(uiColor: .systemGray5)
        }

        return Color(
            red: Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8) / 255,
            blue: Double(value & 0x0000FF) / 255
        )
    }
}

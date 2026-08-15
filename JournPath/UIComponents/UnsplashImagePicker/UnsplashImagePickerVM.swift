import Combine
import Foundation
import SwiftUI

@MainActor
final class UnsplashImagePickerViewModel: ObservableObject {

    @Published var searchText: String
    @Published private(set) var images: [UnsplashImage] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isFetchingMore: Bool = false
    @Published private(set) var errorMessage: String? = nil
    @Published private(set) var errorImage: String = "x.circle"
    @Published private(set) var hasMorePages: Bool = true

    /// Unsplash search relevance falls off a cliff past this point.
    private let maxPages = 9
    private let fallbackQuery = "nature"

    private var currentPage = 1
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    /// Incremented on every new search. Any in-flight response carrying an old
    /// generation is discarded, so a slow page-3 fetch can't append itself to
    /// the results of a search the user has since replaced.
    private var generation = 0

    init(preSearchText: String) {
        self.searchText = preSearchText

        $searchText
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.startSearch(query: query)
            }
            .store(in: &cancellables)
    }

    deinit {
        searchTask?.cancel()
    }

    // MARK: - Entry points

    /// Call from `.task` / `.onAppear` so the pre-filled term loads once.
    func onAppear() {
        guard images.isEmpty, !isLoading else { return }
        startSearch(query: searchText)
    }

    func retry() {
        startSearch(query: searchText)
    }

    private func startSearch(query: String) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.performSearch(query: query)
        }
    }

    // MARK: - Fetching

    private func performSearch(query: String) async {
        generation += 1
        let gen = generation

        isLoading = true
        errorMessage = nil
        currentPage = 1
        hasMorePages = true

        defer { if gen == generation { isLoading = false } }

        do {
            let results = try await fetch(query: query, page: 1)
            guard gen == generation, !Task.isCancelled else { return }

            images = results
            hasMorePages = !results.isEmpty && maxPages > 1

        } catch {
            // A cancelled request surfaces as an error too - never show that.
            guard gen == generation, !Task.isCancelled else { return }

            images = []
            hasMorePages = false
            apply(error)
        }
    }

    func loadMore() async {
        guard !isLoading, !isFetchingMore, hasMorePages, currentPage < maxPages else { return }

        let gen = generation
        let nextPage = currentPage + 1

        isFetchingMore = true
        defer { if gen == generation { isFetchingMore = false } }

        do {
            let results = try await fetch(query: searchText, page: nextPage)
            guard gen == generation, !Task.isCancelled else { return }

            // Unsplash repeats photos across pages often enough to matter -
            // duplicate ids would break ForEach's identity.
            let existing = Set(images.map(\.id))
            images.append(contentsOf: results.filter { !existing.contains($0.id) })

            // Only advance on success, so a failed page is retried rather than skipped.
            currentPage = nextPage
            hasMorePages = !results.isEmpty && nextPage < maxPages

        } catch {
            guard gen == generation, !Task.isCancelled else { return }
            // Keep the existing results on screen; the next scroll retries this page.
            print("[Unsplash] loadMore page \(nextPage) failed: \(error)")
        }
    }

    private func fetch(query: String, page: Int) async throws(APIError) -> [UnsplashImage] {
        let trimmed = query.trimmed
        let term = trimmed.isBlank ? fallbackQuery : trimmed

        let response = try await APIClient.shared.get(
            "image/search",
            query: ["query": term, "page": page],
            as: UnsplashResponse.self
        )
        return response.results
    }

    // MARK: - Errors

    private func apply(_ error: APIError) {
        if case .noInternetConnection = error {
            errorMessage = "You're offline. Check your connection and try again."
            errorImage = "wifi.slash"
        } else {
            errorMessage = "Something went wrong loading images. Please try again."
            errorImage = "x.circle"
        }
        print("[Unsplash] \(error)")
    }
}
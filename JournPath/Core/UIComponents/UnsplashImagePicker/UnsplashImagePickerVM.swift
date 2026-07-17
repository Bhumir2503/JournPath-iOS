import Combine
import FirebaseAppCheck
import FirebaseAuth
import Foundation
import SwiftUI

@MainActor
class UnsplashImagePickerViewModel: ObservableObject {
    @Published var searchText: String
    @Published var images: [UnsplashImage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var errorImage: String = "x.circle"
    @Published var currentPage: Int = 1
    @Published var hasMorePages: Bool = true
    @Published var isFetchingMore: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    init(preSearchText: String) {
        self.searchText = preSearchText

        $searchText
            .dropFirst()
            .debounce(for: .seconds(0.8), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                self.searchTask?.cancel()
                self.searchTask = Task {
                    await self.searchImages(query: query, page: 1)
                }
            }
            .store(in: &cancellables)
    }

    func loadMore() async {
        guard !isFetchingMore && hasMorePages && !isLoading else { return }
        isFetchingMore = true
        currentPage += 1
        await searchImages(query: searchText, page: currentPage)
        isFetchingMore = false
    }

    func searchImages(query: String, page: Int = 1) async {
        let trimmed = query.trimmed
        let trimmedQuery = trimmed.isBlank ? "nature" : trimmed

        if page == 1 {
            isLoading = true
            errorMessage = nil
            currentPage = 1
            hasMorePages = true
        }

        defer { if page == 1 { isLoading = false } }
        if Task.isCancelled { return }

        guard let url = buildURL(query: trimmedQuery, page: page) else { return }

        // 1. Create Request with aggressive caching policy
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        // 2. Token Management
        // We attempt to get tokens, but we don't 'return' immediately if they fail,
        // because the URLCache might already have the data we need.
        let idToken = try? await Auth.auth().currentUser?.getIDToken()
        let appCheckToken = try? await AppCheck.appCheck().token(forcingRefresh: false)

        if let idToken = idToken {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        if let acToken = appCheckToken?.token {
            request.setValue(acToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        }

        do {
            // 3. Perform Network Call
            let (data, response) = try await URLSession.shared.data(for: request)
            if Task.isCancelled { return }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            // 4. Handle Token Expiration (401)
            if httpResponse.statusCode == 401 {
                print("[Unsplash] Token expired, retrying with fresh tokens...")
                let refreshedAC = try? await AppCheck.appCheck().token(forcingRefresh: true)
                request.setValue(refreshedAC?.token, forHTTPHeaderField: "X-Firebase-AppCheck")

                let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
                try handleSuccess(data: retryData, response: retryResponse, page: page)
            } else if (200...299).contains(httpResponse.statusCode) {
                try handleSuccess(data: data, response: response, page: page)
            } else {
                throw URLError(.cannotParseResponse)
            }

        } catch {
            if !Task.isCancelled {
                // Only show error if we have NO images to show (i.e., cache was also empty)
                if page == 1 && images.isEmpty {
                    self.errorMessage = "Unable to load images. Please check your connection."
                }
                print("[Unsplash] Error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func buildURL(query: String, page: Int) -> URL? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://api.bhumir.com/unsplash/search?q=\(encodedQuery)&page=\(page)")
    }

    private func handleSuccess(data: Data, response: URLResponse, page: Int) throws {
        let unsplashResponse = try JSONDecoder().decode(UnsplashResponse.self, from: data)
        let results = unsplashResponse.results

        if results.isEmpty {
            hasMorePages = false
            if page == 1 { self.images = [] }
            return
        }

        if page == 1 {
            self.images = results
        } else {
            let existingIds = Set(self.images.map { $0.id })
            let filtered = results.filter { !existingIds.contains($0.id) }
            self.images.append(contentsOf: filtered)
        }

        if results.count < 20 || page >= 9 {
            hasMorePages = false
        }
    }
}

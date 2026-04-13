import Foundation

@Observable
final class EpisodeListViewModel {
    enum State: Sendable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    private(set) var episodes: [EpisodeDTO] = []
    private(set) var state: State = .idle
    private(set) var isLoadingMore = false
    private(set) var hasMorePages = true
    private(set) var paginationError: String?
    private(set) var toastMessage: String?

    private let repository: any EpisodeRepository
    private let networkMonitor: NetworkMonitor
    private var cursor: PaginationCursor?

    init(
        repository: any EpisodeRepository = SupabaseEpisodeRepository(),
        networkMonitor: NetworkMonitor = NetworkMonitor()
    ) {
        self.repository = repository
        self.networkMonitor = networkMonitor
    }

    var isConnected: Bool { networkMonitor.isConnected }

    // MARK: - Initial Load

    func loadInitialPage() async {
        guard case .idle = state else { return }
        state = .loading
        await fetchFirstPage()
    }

    func retry() async {
        state = .loading
        await fetchFirstPage()
    }

    // MARK: - Pagination

    func loadMoreIfNeeded(currentItem: EpisodeDTO) async {
        guard hasMorePages, !isLoadingMore, paginationError == nil else { return }

        let thresholdIndex = max(episodes.count - 5, 0)
        guard let index = episodes.firstIndex(where: { $0.id == currentItem.id }),
              index >= thresholdIndex else { return }

        isLoadingMore = true
        paginationError = nil

        do {
            let page = try await repository.fetchPage(cursor: cursor, pageSize: 30)
            episodes.append(contentsOf: page.episodes)
            hasMorePages = page.hasMore
            if let last = page.episodes.last {
                cursor = PaginationCursor(publishDate: last.publishDate, id: last.id)
            }
        } catch {
            paginationError = "Failed to load more episodes"
        }

        isLoadingMore = false
    }

    func retryLoadMore() async {
        paginationError = nil
        isLoadingMore = true

        do {
            let page = try await repository.fetchPage(cursor: cursor, pageSize: 30)
            episodes.append(contentsOf: page.episodes)
            hasMorePages = page.hasMore
            if let last = page.episodes.last {
                cursor = PaginationCursor(publishDate: last.publishDate, id: last.id)
            }
        } catch {
            paginationError = "Failed to load more episodes"
        }

        isLoadingMore = false
    }

    // MARK: - Pull to Refresh

    func refresh() async {
        // Step 1: Sync RSS
        do {
            try await repository.syncRSS()
        } catch {
            showToast("Sync failed")
        }

        // Step 2: Re-fetch first page regardless of sync result
        do {
            let page = try await repository.fetchPage(cursor: nil, pageSize: 30)
            episodes = page.episodes
            hasMorePages = page.hasMore
            cursor = page.episodes.last.map { PaginationCursor(publishDate: $0.publishDate, id: $0.id) }
            paginationError = nil
            if case .error = state { state = .loaded }
        } catch {
            showToast("Failed to load episodes")
        }
    }

    // MARK: - Private

    private func fetchFirstPage() async {
        do {
            let page = try await repository.fetchPage(cursor: nil, pageSize: 30)
            episodes = page.episodes
            hasMorePages = page.hasMore
            cursor = page.episodes.last.map { PaginationCursor(publishDate: $0.publishDate, id: $0.id) }
            state = .loaded
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}

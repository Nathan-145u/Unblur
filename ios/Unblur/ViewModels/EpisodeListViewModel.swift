import Foundation

enum LoadState {
    case idle
    case loading
    case loaded
    case error
    case offline
}

@Observable
final class EpisodeListViewModel {
    private(set) var episodes: [Episode] = []
    private(set) var loadState: LoadState = .idle
    private(set) var hasMore = true
    private(set) var isLoadingMore = false
    private(set) var paginationFailed = false
    private(set) var refreshFailed = false

    private let service: any EpisodeService
    private let pageSize: Int
    private var cursor: (Date, UUID)?

    init(service: any EpisodeService = SupabaseEpisodeService(), pageSize: Int = 30) {
        self.service = service
        self.pageSize = pageSize
    }

    func loadEpisodes() async {
        loadState = .loading
        cursor = nil
        paginationFailed = false
        refreshFailed = false

        do {
            episodes = try await fetchPage(cursor: nil)
            loadState = .loaded
        } catch {
            episodes = []
            loadState = isOfflineError(error) ? .offline : .error
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true

        do {
            let page = try await fetchPage(cursor: cursor)
            episodes.append(contentsOf: page)
            paginationFailed = false
        } catch {
            paginationFailed = true
        }

        isLoadingMore = false
    }

    func refresh() async {
        let previousCursor = cursor
        cursor = nil

        do {
            episodes = try await fetchPage(cursor: nil)
            loadState = .loaded
            refreshFailed = false
        } catch {
            cursor = previousCursor
            refreshFailed = true
        }
    }

    private func fetchPage(cursor: (Date, UUID)?) async throws -> [Episode] {
        let page = try await service.fetchEpisodes(cursor: cursor, limit: pageSize)
        hasMore = page.count >= pageSize
        updateCursor(from: page)
        return page
    }

    private func updateCursor(from page: [Episode]) {
        guard let last = page.last else { return }
        self.cursor = (last.publishDate, last.id)
    }

    private func isOfflineError(_ error: Error) -> Bool {
        (error as? URLError)?.code == .notConnectedToInternet
    }
}

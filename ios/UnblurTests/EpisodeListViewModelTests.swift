import Testing
import Foundation
@testable import Unblur

// MARK: - Mock Repository

final class MockEpisodeRepository: EpisodeRepository, @unchecked Sendable {
    let pages: [[EpisodeDTO]]
    let syncRSSError: (any Error)?
    let fetchError: (any Error)?

    init(
        pages: [[EpisodeDTO]] = [],
        syncRSSError: (any Error)? = nil,
        fetchError: (any Error)? = nil
    ) {
        self.pages = pages
        self.syncRSSError = syncRSSError
        self.fetchError = fetchError
    }

    func fetchPage(cursor: PaginationCursor?, pageSize: Int) async throws -> EpisodePage {
        if let fetchError { throw fetchError }

        let pageIndex = cursor == nil ? 0 : 1
        let episodes = pageIndex < pages.count ? pages[pageIndex] : []
        return EpisodePage(
            episodes: episodes,
            hasMore: episodes.count >= pageSize
        )
    }

    func syncRSS() async throws {
        if let syncRSSError { throw syncRSSError }
    }
}

// MARK: - Tests

@Test("Initial load transitions to loaded state")
@MainActor
func initialLoad() async {
    let episodes = makeEpisodes(count: 5)
    let repo = MockEpisodeRepository(pages: [episodes])
    let vm = EpisodeListViewModel(repository: repo, networkMonitor: NetworkMonitor())

    await vm.loadInitialPage()

    #expect(vm.episodes.count == 5)
    if case .loaded = vm.state {
        // correct
    } else {
        Issue.record("Expected .loaded state, got \(vm.state)")
    }
}

@Test("Initial load failure transitions to error state")
@MainActor
func initialLoadFailure() async {
    let repo = MockEpisodeRepository(fetchError: URLError(.notConnectedToInternet))
    let vm = EpisodeListViewModel(repository: repo, networkMonitor: NetworkMonitor())

    await vm.loadInitialPage()

    if case .error = vm.state {
        // correct
    } else {
        Issue.record("Expected .error state, got \(vm.state)")
    }
}

@Test("Retry after error reloads data")
@MainActor
func retryAfterError() async {
    let repo = MockEpisodeRepository(fetchError: URLError(.notConnectedToInternet))
    let vm = EpisodeListViewModel(repository: repo, networkMonitor: NetworkMonitor())

    await vm.loadInitialPage()
    if case .error = vm.state { } else {
        Issue.record("Expected error state first")
    }

    await vm.retry()
    if case .error = vm.state { } else {
        Issue.record("Expected error state after retry with bad repo")
    }
}

@Test("hasMorePages is false when page returns fewer than pageSize")
@MainActor
func hasMorePagesFalse() async {
    let episodes = makeEpisodes(count: 10)
    let repo = MockEpisodeRepository(pages: [episodes])
    let vm = EpisodeListViewModel(repository: repo, networkMonitor: NetworkMonitor())

    await vm.loadInitialPage()

    #expect(!vm.hasMorePages)
}

// MARK: - Helpers

private func makeEpisodes(count: Int) -> [EpisodeDTO] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    return (0..<count).map { i in
        let json = """
        {
            "id": "\(UUID().uuidString.lowercased())",
            "title": "Episode \(i)",
            "publish_date": "2026-04-\(String(format: "%02d", max(1, 10 - i)))T10:00:00+00:00",
            "duration": \(600 + i * 60),
            "remote_audio_url": "https://example.com/audio-\(i).mp3",
            "artwork_url": null,
            "source_type": "rss",
            "transcription_status": "none",
            "translation_status": "none"
        }
        """.data(using: .utf8)!
        return try! decoder.decode(EpisodeDTO.self, from: json)
    }
}

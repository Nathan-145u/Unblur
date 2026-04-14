import Foundation
import Testing
@testable import Unblur

private func makeEpisodes(count: Int, startDate: Date = Date()) -> [Episode] {
    (0..<count).map { i in
        Episode(
            id: UUID(),
            title: "Episode \(i + 1)",
            publishDate: startDate.addingTimeInterval(Double(-i * 3600)),
            duration: 1800,
            remoteAudioUrl: "https://example.com/ep\(i).mp3",
            artworkUrl: nil,
            sourceType: "rss",
            transcriptionStatus: "none",
            translationStatus: "none"
        )
    }
}

@Test("Initial load succeeds")
@MainActor
func initialLoadSuccess() async {
    let episodes = makeEpisodes(count: 5)
    let service = MockEpisodeService(episodes: episodes)
    let vm = EpisodeListViewModel(service: service)

    await vm.loadEpisodes()

    #expect(vm.episodes.count == 5)
    #expect(vm.loadState == .loaded)
    #expect(vm.hasMore == false)
}

@Test("Initial load failure sets error state")
@MainActor
func initialLoadFailure() async {
    let service = MockEpisodeService(error: URLError(.badServerResponse))
    let vm = EpisodeListViewModel(service: service)

    await vm.loadEpisodes()

    #expect(vm.episodes.isEmpty)
    #expect(vm.loadState == .error)
}

@Test("Initial load with network error sets offline state")
@MainActor
func initialLoadOffline() async {
    let service = MockEpisodeService(error: URLError(.notConnectedToInternet))
    let vm = EpisodeListViewModel(service: service)

    await vm.loadEpisodes()

    #expect(vm.loadState == .offline)
}

@Test("Pagination appends data")
@MainActor
func paginationAppendsData() async {
    let episodes = makeEpisodes(count: 50)
    let service = MockEpisodeService(episodes: episodes)
    let vm = EpisodeListViewModel(service: service, pageSize: 30)

    await vm.loadEpisodes()
    #expect(vm.episodes.count == 30)
    #expect(vm.hasMore == true)

    await vm.loadMore()
    #expect(vm.episodes.count == 50)
    #expect(vm.hasMore == false)
}

@Test("Refresh resets state")
@MainActor
func refreshResetsState() async {
    let episodes = makeEpisodes(count: 5)
    let service = MockEpisodeService(episodes: episodes)
    let vm = EpisodeListViewModel(service: service)

    await vm.loadEpisodes()
    #expect(vm.episodes.count == 5)

    await vm.refresh()
    #expect(vm.episodes.count == 5)
    #expect(vm.loadState == .loaded)
}

@Test("Duplicate pagination calls ignored")
@MainActor
func duplicatePaginationIgnored() async {
    let episodes = makeEpisodes(count: 50)
    let service = MockEpisodeService(episodes: episodes)
    let vm = EpisodeListViewModel(service: service, pageSize: 30)

    await vm.loadEpisodes()

    // After loadMore, should have all 50 episodes
    await vm.loadMore()
    #expect(vm.episodes.count == 50)

    // Second loadMore should be no-op since hasMore is false
    await vm.loadMore()
    #expect(vm.episodes.count == 50)
}

@Test("hasMore is false when page returns fewer than pageSize items")
@MainActor
func hasMoreFalseWhenPageSmall() async {
    let episodes = makeEpisodes(count: 10)
    let service = MockEpisodeService(episodes: episodes)
    let vm = EpisodeListViewModel(service: service, pageSize: 30)

    await vm.loadEpisodes()
    #expect(vm.hasMore == false)
    #expect(vm.episodes.count == 10)
}

@Test("loadMore does nothing when hasMore is false")
@MainActor
func loadMoreNoop() async {
    let episodes = makeEpisodes(count: 5)
    let service = MockEpisodeService(episodes: episodes)
    let vm = EpisodeListViewModel(service: service, pageSize: 30)

    await vm.loadEpisodes()
    #expect(vm.hasMore == false)

    await vm.loadMore()
    #expect(vm.episodes.count == 5)
}

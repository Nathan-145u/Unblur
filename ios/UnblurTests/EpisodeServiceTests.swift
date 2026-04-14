import Foundation
import Testing
@testable import Unblur

struct MockEpisodeService: EpisodeService {
    let episodes: [Episode]
    let error: Error?

    init(episodes: [Episode] = [], error: Error? = nil) {
        self.episodes = episodes
        self.error = error
    }

    func fetchEpisodes(cursor: (Date, UUID)?, limit: Int) async throws -> [Episode] {
        if let error { throw error }
        guard let (cursorDate, cursorId) = cursor else {
            return Array(episodes.prefix(limit))
        }
        let filtered = episodes.filter { episode in
            episode.publishDate < cursorDate
            || (episode.publishDate == cursorDate && episode.id.uuidString < cursorId.uuidString)
        }
        return Array(filtered.prefix(limit))
    }
}

@Test("Mock service returns expected episodes")
func mockServiceReturnsExpectedEpisodes() async throws {
    let testEpisodes = [
        Episode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "Episode 1",
            publishDate: Date(timeIntervalSince1970: 1_700_000_000),
            duration: 3600,
            remoteAudioUrl: "https://example.com/ep1.mp3",
            artworkUrl: "https://example.com/art1.jpg",
            sourceType: "rss",
            transcriptionStatus: "none",
            translationStatus: "none"
        ),
        Episode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Episode 2",
            publishDate: Date(timeIntervalSince1970: 1_700_100_000),
            duration: 1800,
            remoteAudioUrl: "https://example.com/ep2.mp3",
            artworkUrl: nil,
            sourceType: "rss",
            transcriptionStatus: "none",
            translationStatus: "none"
        ),
    ]

    let service = MockEpisodeService(episodes: testEpisodes)
    let result = try await service.fetchEpisodes(cursor: nil, limit: 30)

    #expect(result.count == 2)
    #expect(result[0].title == "Episode 1")
    #expect(result[1].artworkUrl == nil)
}

@Test("Mock service returns empty array when no episodes")
func mockServiceReturnsEmptyArray() async throws {
    let service = MockEpisodeService(episodes: [])
    let result = try await service.fetchEpisodes(cursor: nil, limit: 30)
    #expect(result.isEmpty)
}

@Test("Mock service throws error when configured")
func mockServiceThrowsError() async {
    let service = MockEpisodeService(error: URLError(.notConnectedToInternet))
    await #expect(throws: URLError.self) {
        try await service.fetchEpisodes(cursor: nil, limit: 30)
    }
}

@Test("Episode conforms to Decodable with snake_case keys")
func episodeDecodesFromJSON() throws {
    let json = """
    {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "title": "Test Episode",
        "publish_date": "2024-01-15T10:30:00Z",
        "duration": 1234,
        "remote_audio_url": "https://example.com/audio.mp3",
        "artwork_url": "https://example.com/art.jpg",
        "source_type": "rss",
        "transcription_status": "none",
        "translation_status": "none"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let episode = try decoder.decode(Episode.self, from: json)

    #expect(episode.id == UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000"))
    #expect(episode.title == "Test Episode")
    #expect(episode.duration == 1234)
    #expect(episode.remoteAudioUrl == "https://example.com/audio.mp3")
    #expect(episode.artworkUrl == "https://example.com/art.jpg")
    #expect(episode.sourceType == "rss")
}

@Test("Episode decodes with null artwork_url")
func episodeDecodesNullArtwork() throws {
    let json = """
    {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "title": "No Art",
        "publish_date": "2024-01-15T10:30:00Z",
        "duration": 0,
        "remote_audio_url": "https://example.com/audio.mp3",
        "artwork_url": null,
        "source_type": "rss",
        "transcription_status": "none",
        "translation_status": "none"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let episode = try decoder.decode(Episode.self, from: json)

    #expect(episode.artworkUrl == nil)
    #expect(episode.duration == 0)
}

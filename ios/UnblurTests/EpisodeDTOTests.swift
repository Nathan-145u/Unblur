import Testing
import Foundation
@testable import Unblur

@Test("EpisodeDTO decodes valid JSON with all fields")
func decodesValidJSON() throws {
    let json = """
    {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "title": "Episode One",
        "publish_date": "2026-04-10T10:00:00+00:00",
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

    let episode = try decoder.decode(EpisodeDTO.self, from: json)

    #expect(episode.id == UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000"))
    #expect(episode.title == "Episode One")
    #expect(episode.duration == 1234)
    #expect(episode.remoteAudioUrl == "https://example.com/audio.mp3")
    #expect(episode.artworkUrl == "https://example.com/art.jpg")
    #expect(episode.sourceType == "rss")
}

@Test("EpisodeDTO decodes JSON with null artwork_url")
func decodesNullArtwork() throws {
    let json = """
    {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "title": "No Art Episode",
        "publish_date": "2026-04-10T10:00:00+00:00",
        "duration": 600,
        "remote_audio_url": "https://example.com/audio.mp3",
        "artwork_url": null,
        "source_type": "rss",
        "transcription_status": "none",
        "translation_status": "none"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let episode = try decoder.decode(EpisodeDTO.self, from: json)

    #expect(episode.artworkUrl == nil)
}

@Test("formattedDuration formats seconds-only")
func formattedDurationSeconds() {
    let episode = makeEpisode(duration: 45)
    #expect(episode.formattedDuration == "0:45")
}

@Test("formattedDuration formats minutes and seconds")
func formattedDurationMinutes() {
    let episode = makeEpisode(duration: 754)
    #expect(episode.formattedDuration == "12:34")
}

@Test("formattedDuration formats hours")
func formattedDurationHours() {
    let episode = makeEpisode(duration: 3661)
    #expect(episode.formattedDuration == "1:01:01")
}

// MARK: - Helpers

private func makeEpisode(duration: Int) -> EpisodeDTO {
    let json = """
    {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "title": "Test",
        "publish_date": "2026-04-10T10:00:00+00:00",
        "duration": \(duration),
        "remote_audio_url": "https://example.com/audio.mp3",
        "artwork_url": null,
        "source_type": "rss",
        "transcription_status": "none",
        "translation_status": "none"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    return try! decoder.decode(EpisodeDTO.self, from: json)
}

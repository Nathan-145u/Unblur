import Foundation

struct Episode: Decodable, Identifiable, Sendable, Equatable {
    let id: UUID
    let title: String
    let publishDate: Date
    let duration: Int
    let remoteAudioUrl: String
    let artworkUrl: String?
    let sourceType: String
    let transcriptionStatus: String
    let translationStatus: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case publishDate = "publish_date"
        case duration
        case remoteAudioUrl = "remote_audio_url"
        case artworkUrl = "artwork_url"
        case sourceType = "source_type"
        case transcriptionStatus = "transcription_status"
        case translationStatus = "translation_status"
    }
}

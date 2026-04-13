import Foundation

struct EpisodeDTO: Decodable, Identifiable, Sendable {
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
        case id, title, duration
        case publishDate = "publish_date"
        case remoteAudioUrl = "remote_audio_url"
        case artworkUrl = "artwork_url"
        case sourceType = "source_type"
        case transcriptionStatus = "transcription_status"
        case translationStatus = "translation_status"
    }

    var formattedDuration: String {
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()

        if let daysAgo = calendar.dateComponents([.day], from: publishDate, to: now).day, daysAgo < 7 {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: publishDate, relativeTo: now)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: publishDate)
    }
}

import Foundation
import Supabase

struct EpisodePage: Sendable {
    let episodes: [EpisodeDTO]
    let hasMore: Bool
}

struct PaginationCursor: Sendable {
    let publishDate: Date
    let id: UUID
}

protocol EpisodeRepository: Sendable {
    func fetchPage(cursor: PaginationCursor?, pageSize: Int) async throws -> EpisodePage
    func syncRSS() async throws
}

struct SupabaseEpisodeRepository: EpisodeRepository {
    private let client: SupabaseClient
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init(client: SupabaseClient = SupabaseClientFactory.shared) {
        self.client = client
    }

    func fetchPage(cursor: PaginationCursor?, pageSize: Int = 30) async throws -> EpisodePage {
        var query = client
            .from("episodes_view")
            .select()

        if let cursor {
            let dateString = Self.iso8601.string(from: cursor.publishDate)
            let idString = cursor.id.uuidString.lowercased()
            query = query.or("publish_date.lt.\(dateString),and(publish_date.eq.\(dateString),id.lt.\(idString))")
        }

        let episodes: [EpisodeDTO] = try await query
            .order("publish_date", ascending: false)
            .order("id", ascending: false)
            .limit(pageSize)
            .execute()
            .value

        return EpisodePage(
            episodes: episodes,
            hasMore: episodes.count >= pageSize
        )
    }

    func syncRSS() async throws {
        _ = try await client.functions.invoke("sync-rss")
    }
}

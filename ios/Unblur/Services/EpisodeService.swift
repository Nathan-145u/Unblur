import Foundation
import Supabase

protocol EpisodeService: Sendable {
    func fetchEpisodes(cursor: (Date, UUID)?, limit: Int) async throws -> [Episode]
}

struct SupabaseEpisodeService: EpisodeService {
    private let client: SupabaseClient

    init(client: SupabaseClient = .shared) {
        self.client = client
    }

    func fetchEpisodes(cursor: (Date, UUID)?, limit: Int) async throws -> [Episode] {
        var query = client
            .from("episodes_view")
            .select()

        if let (cursorDate, cursorId) = cursor {
            let dateString = ISO8601DateFormatter().string(from: cursorDate)
            query = query.or(
                "publish_date.lt.\(dateString),and(publish_date.eq.\(dateString),id.lt.\(cursorId))"
            )
        }

        let episodes: [Episode] = try await query
            .order("publish_date", ascending: false)
            .order("id", ascending: false)
            .limit(limit)
            .execute()
            .value

        return episodes
    }
}

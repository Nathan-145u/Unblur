import Foundation

enum UITestMode: String {
    case happy
    case empty
    case errorInitial = "error_initial"
    case offline
    case failPagination = "fail_pagination"

    static let launchArgument = "UITEST_MODE"

    static func fromLaunchEnvironment() -> UITestMode? {
        if let raw = UserDefaults.standard.string(forKey: launchArgument),
           let mode = UITestMode(rawValue: raw) {
            return mode
        }
        let arguments = ProcessInfo.processInfo.arguments
        for needle in [launchArgument, "-\(launchArgument)"] {
            if let index = arguments.firstIndex(of: needle),
               index + 1 < arguments.count,
               let mode = UITestMode(rawValue: arguments[index + 1]) {
                return mode
            }
        }
        return nil
    }
}

struct UITestEpisodeService: EpisodeService {
    let mode: UITestMode
    let pageSize: Int

    init(mode: UITestMode, pageSize: Int = 30) {
        self.mode = mode
        self.pageSize = pageSize
    }

    func fetchEpisodes(cursor: (Date, UUID)?, limit: Int) async throws -> [Episode] {
        try await Task.sleep(nanoseconds: 200_000_000)

        switch mode {
        case .empty:
            return []

        case .errorInitial:
            throw NSError(domain: "UITestEpisodeService", code: 500)

        case .offline:
            throw URLError(.notConnectedToInternet)

        case .happy:
            return Self.page(for: cursor, pageSize: pageSize, total: 45)

        case .failPagination:
            if cursor == nil {
                return Self.page(for: nil, pageSize: pageSize, total: 60)
            }
            throw URLError(.timedOut)
        }
    }

    private static func page(for cursor: (Date, UUID)?, pageSize: Int, total: Int) -> [Episode] {
        let all = fixtureEpisodes(count: total)
        let startIndex: Int
        if let (cursorDate, cursorId) = cursor,
           let cursorIndex = all.firstIndex(where: { $0.publishDate == cursorDate && $0.id == cursorId }) {
            startIndex = cursorIndex + 1
        } else {
            startIndex = 0
        }
        let endIndex = min(startIndex + pageSize, all.count)
        guard startIndex < endIndex else { return [] }
        return Array(all[startIndex..<endIndex])
    }

    private static func fixtureEpisodes(count: Int) -> [Episode] {
        let base = Date(timeIntervalSince1970: 1_710_000_000)
        return (0..<count).map { index in
            Episode(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
                title: "UITest Episode #\(index + 1)",
                publishDate: base.addingTimeInterval(TimeInterval(-index) * 86_400),
                duration: (index % 3 == 0) ? 0 : (900 + index * 60),
                remoteAudioUrl: "https://example.com/audio/\(index).mp3",
                artworkUrl: nil,
                sourceType: "rss",
                transcriptionStatus: "pending",
                translationStatus: "pending"
            )
        }
    }
}

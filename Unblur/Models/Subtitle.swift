//
//  Subtitle.swift
//  Unblur — v0.2 sentence-level subtitle with optional word timings + v0.3 translation
//

import Foundation
import SwiftData

@Model
final class Subtitle {
    @Attribute(.unique) var id: UUID
    var index: Int
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    /// JSON-encoded `[WordTiming]` (SwiftData stores this as a String for simplicity).
    var wordTimingsJSON: String?
    /// v0.3 — Chinese translation, populated lazily.
    var translation: String?

    var episode: Episode?

    init(
        id: UUID = UUID(),
        index: Int,
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        wordTimingsJSON: String? = nil,
        translation: String? = nil
    ) {
        self.id = id
        self.index = index
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.wordTimingsJSON = wordTimingsJSON
        self.translation = translation
    }

    var wordTimings: [WordTiming] {
        guard let json = wordTimingsJSON,
              let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([WordTiming].self, from: data)
        else { return [] }
        return arr
    }
}

struct WordTiming: Codable, Hashable {
    var word: String
    var start: TimeInterval
    var end: TimeInterval
}

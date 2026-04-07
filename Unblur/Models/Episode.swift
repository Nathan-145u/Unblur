//
//  Episode.swift
//  Unblur
//

import Foundation
import SwiftData

@Model
final class Episode {
    @Attribute(.unique) var id: UUID
    var title: String
    var publishDate: Date
    var duration: TimeInterval
    var remoteAudioURL: String
    var artworkURL: String?
    var localAudioFilename: String?
    var downloadProgress: Double
    var lastPlayPosition: TimeInterval

    // v0.2 — transcription state
    var transcriptionStatus: String  // "none" | "running" | "done" | "failed"
    @Relationship(deleteRule: .cascade, inverse: \Subtitle.episode)
    var subtitles: [Subtitle] = []

    init(
        id: UUID = UUID(),
        title: String,
        publishDate: Date,
        duration: TimeInterval,
        remoteAudioURL: String,
        artworkURL: String? = nil,
        localAudioFilename: String? = nil,
        downloadProgress: Double = 0,
        lastPlayPosition: TimeInterval = 0,
        transcriptionStatus: String = "none"
    ) {
        self.id = id
        self.title = title
        self.publishDate = publishDate
        self.duration = duration
        self.remoteAudioURL = remoteAudioURL
        self.artworkURL = artworkURL
        self.localAudioFilename = localAudioFilename
        self.downloadProgress = downloadProgress
        self.lastPlayPosition = lastPlayPosition
        self.transcriptionStatus = transcriptionStatus
    }

    var isDownloaded: Bool { localAudioFilename != nil }

    var localAudioURL: URL? {
        guard let name = localAudioFilename else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(name)
    }
}

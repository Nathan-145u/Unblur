//
//  TranscriptionService.swift
//  Unblur — v0.2 transcription
//
//  Architecture note: this is a transcription abstraction with a Speech-framework
//  backend (on-device when available). The spec calls for WhisperKit; that can be
//  swapped in by replacing `runRecognition(...)` once the SPM dep is added in Xcode.
//

import Foundation
import Speech
import AVFoundation
import SwiftData
import Observation

@MainActor
@Observable
final class TranscriptionService {
    static let shared = TranscriptionService()

    /// episodeID → progress 0…1
    private(set) var inFlight: [UUID: Double] = [:]

    private var queue: [UUID] = []
    private var isRunning = false

    func transcribe(_ episode: Episode, context: ModelContext) async {
        guard episode.transcriptionStatus != "running",
              episode.transcriptionStatus != "done",
              episode.localAudioURL != nil
        else { return }
        episode.transcriptionStatus = "running"
        inFlight[episode.id] = 0
        try? context.save()

        do {
            try await requestAuthorization()
            let result = try await runRecognition(for: episode)
            // Wipe and persist subtitles
            for s in episode.subtitles { context.delete(s) }
            for (i, seg) in result.enumerated() {
                let sub = Subtitle(
                    index: i,
                    startTime: seg.start,
                    endTime: seg.end,
                    text: seg.text,
                    wordTimingsJSON: seg.wordTimingsJSON
                )
                sub.episode = episode
                context.insert(sub)
            }
            episode.transcriptionStatus = "done"
            inFlight[episode.id] = nil
            try? context.save()
        } catch {
            episode.transcriptionStatus = "failed"
            inFlight[episode.id] = nil
            try? context.save()
        }
    }

    private func requestAuthorization() async throws {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { return }
        let granted: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard granted == .authorized else {
            throw NSError(domain: "Unblur.Transcription", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
        }
    }

    struct Segment {
        var start: TimeInterval
        var end: TimeInterval
        var text: String
        var wordTimingsJSON: String?
    }

    /// Backend stub. Uses SFSpeechRecognizer with `requiresOnDeviceRecognition`.
    /// Returns sentence-level segments with embedded word timings.
    private func runRecognition(for episode: Episode) async throws -> [Segment] {
        guard let url = episode.localAudioURL else { return [] }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable
        else {
            throw NSError(domain: "Unblur.Transcription", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Recognizer unavailable"])
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        let result: SFSpeechRecognitionResult = try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { res, err in
                if let err = err {
                    cont.resume(throwing: err); return
                }
                if let res = res, res.isFinal {
                    cont.resume(returning: res)
                }
            }
        }

        let words: [WordTiming] = result.bestTranscription.segments.map { seg in
            WordTiming(word: seg.substring,
                       start: seg.timestamp,
                       end: seg.timestamp + seg.duration)
        }
        return Self.groupIntoSentences(words: words)
    }

    /// Splits the flat word stream into sentences using punctuation and pauses.
    static func groupIntoSentences(words: [WordTiming]) -> [Segment] {
        guard !words.isEmpty else { return [] }
        var segments: [Segment] = []
        var bucket: [WordTiming] = []
        let punctuation = Set<Character>([".", "!", "?"])

        func flush() {
            guard !bucket.isEmpty else { return }
            let text = bucket.map { $0.word }.joined(separator: " ")
            let start = bucket.first!.start
            let end = bucket.last!.end
            let json = (try? JSONEncoder().encode(bucket)).flatMap {
                String(data: $0, encoding: .utf8)
            }
            segments.append(Segment(start: start, end: end, text: text, wordTimingsJSON: json))
            bucket.removeAll(keepingCapacity: true)
        }

        for (i, w) in words.enumerated() {
            bucket.append(w)
            let lastChar = w.word.last
            let endsSentence = lastChar.map { punctuation.contains($0) } ?? false
            let nextGap: TimeInterval = (i + 1 < words.count) ? (words[i + 1].start - w.end) : 0
            if endsSentence || nextGap > 0.7 || bucket.count >= 18 {
                flush()
            }
        }
        flush()
        return segments
    }
}

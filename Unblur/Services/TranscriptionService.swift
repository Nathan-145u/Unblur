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
    /// episodeID → last error message
    private(set) var lastError: [UUID: String] = [:]

    private var queue: [UUID] = []
    private var isRunning = false

    func transcribe(_ episode: Episode, context: ModelContext) async {
        guard episode.transcriptionStatus != "running",
              episode.transcriptionStatus != "done",
              episode.localAudioURL != nil
        else { return }
        episode.transcriptionStatus = "running"
        inFlight[episode.id] = 0
        lastError[episode.id] = nil
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
            let nsErr = error as NSError
            NSLog("[Unblur] Transcription failed for \(episode.title): \(error)")
            let msg: String
            // kLSRErrorDomain Code=201 means Siri/Dictation is disabled at the OS level.
            if nsErr.domain == "kLSRErrorDomain" && nsErr.code == 201 {
                #if os(macOS)
                msg = "Speech recognition needs Dictation enabled. Open System Settings → Keyboard, turn on \"Dictation\", then click Retry."
                #else
                msg = "Speech recognition needs Dictation enabled. Open Settings → General → Keyboard → Enable Dictation, then click Retry."
                #endif
            } else {
                msg = nsErr.localizedDescription
            }
            episode.transcriptionStatus = "failed"
            inFlight[episode.id] = nil
            lastError[episode.id] = msg
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

    /// Backend stub. Decodes the local audio file with AVAssetReader (handles MP3
    /// and other compressed formats) and feeds PCM buffers into a buffer-based
    /// SFSpeech request. This bypasses the ~1-minute limit of the URL-based
    /// request and works with arbitrary input formats. Requires on-device
    /// recognition support.
    private func runRecognition(for episode: Episode) async throws -> [Segment] {
        guard let url = episode.localAudioURL else { return [] }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            throw err("Speech recognizer unavailable for en-US")
        }
        guard recognizer.isAvailable else {
            throw err("Speech recognizer is not currently available")
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw err("On-device speech recognition is not available on this device. Open System Settings → General → Language & Region and ensure English is added so the on-device model can download.")
        }

        let asset = AVURLAsset(url: url)
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw err("Failed to open audio file: \(error.localizedDescription)")
        }

        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = tracks.first else {
            throw err("No audio track in file")
        }

        // Decode to 16 kHz mono PCM Int16 (Speech accepts this readily).
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        guard reader.canAdd(trackOutput) else { throw err("Cannot read audio track") }
        reader.add(trackOutput)
        guard reader.startReading() else {
            throw err("Reader failed to start: \(reader.error?.localizedDescription ?? "unknown")")
        }

        let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                   sampleRate: 16_000,
                                   channels: 1,
                                   interleaved: true)!

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true
        if #available(macOS 13, iOS 16, *) {
            request.addsPunctuation = true
        }

        // Pump PCM buffers into the request. Do this off the main actor.
        let pumpTask = Task.detached(priority: .userInitiated) {
            while reader.status == .reading {
                guard let sample = trackOutput.copyNextSampleBuffer() else { break }
                if let buffer = Self.pcmBuffer(from: sample, format: format) {
                    request.append(buffer)
                }
                CMSampleBufferInvalidate(sample)
            }
            request.endAudio()
        }

        let result: SFSpeechRecognitionResult = try await withCheckedThrowingContinuation { cont in
            var resumed = false
            recognizer.recognitionTask(with: request) { res, err in
                if resumed { return }
                if let err = err {
                    resumed = true
                    cont.resume(throwing: err); return
                }
                if let res = res, res.isFinal {
                    resumed = true
                    cont.resume(returning: res)
                }
            }
        }
        _ = await pumpTask.value

        let words: [WordTiming] = result.bestTranscription.segments.map { seg in
            WordTiming(word: seg.substring,
                       start: seg.timestamp,
                       end: seg.timestamp + seg.duration)
        }
        return Self.groupIntoSentences(words: words)
    }

    private func err(_ message: String) -> NSError {
        NSError(domain: "Unblur.Transcription", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }

    /// Convert a CMSampleBuffer of Int16 PCM into an AVAudioPCMBuffer matching `format`.
    nonisolated static func pcmBuffer(from sample: CMSampleBuffer,
                                      format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sample) else { return nil }
        let length = CMBlockBufferGetDataLength(blockBuffer)
        let frames = AVAudioFrameCount(length / MemoryLayout<Int16>.size)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            return nil
        }
        pcmBuffer.frameLength = frames
        guard let dest = pcmBuffer.int16ChannelData?[0] else { return nil }
        var status: OSStatus = noErr
        status = CMBlockBufferCopyDataBytes(blockBuffer,
                                            atOffset: 0,
                                            dataLength: length,
                                            destination: dest)
        return status == noErr ? pcmBuffer : nil
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

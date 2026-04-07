//
//  AudioPlayerManager.swift
//  Unblur
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class AudioPlayerManager {
    static let shared = AudioPlayerManager()

    private(set) var currentEpisode: Episode?
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0

    private var player: AVPlayer?
    private var timeObserver: Any?

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    func load(_ episode: Episode) {
        // Save position of previous episode
        savePosition()

        guard let url = episode.localAudioURL else { return }
        currentEpisode = episode

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.rate = 0
        player = p

        if let observer = timeObserver { p.removeTimeObserver(observer) }
        timeObserver = p.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = CMTimeGetSeconds(time)
                if let dur = self.player?.currentItem?.duration.seconds, dur.isFinite {
                    self.duration = dur
                }
            }
        }

        // Restore last position
        let resume = episode.lastPlayPosition
        if resume > 1 {
            p.seek(to: CMTime(seconds: resume, preferredTimescale: 600))
        }
        currentTime = resume
        duration = episode.duration
    }

    func play() {
        guard let p = player else { return }
        p.rate = playbackRate
        isPlaying = true
    }

    func pause() {
        player?.rate = 0
        isPlaying = false
        savePosition()
    }

    func togglePlayPause() { isPlaying ? pause() : play() }

    func seek(to seconds: TimeInterval) {
        guard let p = player else { return }
        p.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600))
        currentTime = seconds
    }

    func skip(by delta: TimeInterval) {
        seek(to: currentTime + delta)
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying { player?.rate = rate }
    }

    func savePosition() {
        guard let ep = currentEpisode else { return }
        ep.lastPlayPosition = currentTime
    }
}

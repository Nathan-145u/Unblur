//
//  MiniPlayerView.swift
//  Unblur
//

import SwiftUI

struct MiniPlayerView: View {
    let onTap: () -> Void
    private var player: AudioPlayerManager { AudioPlayerManager.shared }

    var body: some View {
        if let ep = player.currentEpisode {
            VStack(spacing: 0) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                HStack(spacing: 12) {
                    Text(ep.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 8)
            .onTapGesture(perform: onTap)
        }
    }

    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return min(1, max(0, player.currentTime / player.duration))
    }
}

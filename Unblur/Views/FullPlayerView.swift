//
//  FullPlayerView.swift
//  Unblur
//

import SwiftUI

struct FullPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    private var player: AudioPlayerManager { AudioPlayerManager.shared }

    @State private var dragging = false
    @State private var dragValue: Double = 0
    @State private var showSubtitles = true
    @State private var showChat = false

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        if let ep = player.currentEpisode {
            NavigationStack {
                VStack(spacing: 16) {
                    artwork(for: ep)
                    Text(ep.title).font(.headline).multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(AppFormatters.display.string(from: ep.publishDate))
                        .font(.caption).foregroundStyle(.secondary)

                    progressBar
                    timeRow
                    controlRow
                    speedPicker

                    if showSubtitles {
                        Divider()
                        SubtitleScrollView(episode: ep)
                            .frame(maxHeight: .infinity)
                    }
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showSubtitles.toggle() } label: {
                            Image(systemName: showSubtitles ? "captions.bubble.fill" : "captions.bubble")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showChat = true } label: {
                            Image(systemName: "sparkles")
                        }
                    }
                }
                .sheet(isPresented: $showChat) {
                    ChatPanelView(episode: ep)
                }
            }
        } else {
            Text("Nothing playing").padding()
        }
    }

    @ViewBuilder
    private func artwork(for ep: Episode) -> some View {
        if let urlStr = ep.artworkURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit()
                default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(maxWidth: 220, maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.2))
                .frame(width: 220, height: 220)
        }
    }

    private var progressBar: some View {
        let total = max(player.duration, 1)
        let value = dragging ? dragValue : player.currentTime
        return Slider(
            value: Binding(
                get: { value },
                set: { newVal in
                    dragValue = newVal
                    dragging = true
                }
            ),
            in: 0...total,
            onEditingChanged: { editing in
                if !editing {
                    player.seek(to: dragValue)
                    dragging = false
                }
            }
        )
    }

    private var timeRow: some View {
        HStack {
            Text(AppFormatters.duration(dragging ? dragValue : player.currentTime))
            Spacer()
            Text(AppFormatters.duration(player.duration))
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private var controlRow: some View {
        HStack(spacing: 40) {
            Button { player.skip(by: -15) } label: {
                Image(systemName: "gobackward.15").font(.title)
            }
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            Button { player.skip(by: 15) } label: {
                Image(systemName: "goforward.15").font(.title)
            }
        }
        .buttonStyle(.plain)
    }

    private var speedPicker: some View {
        HStack(spacing: 8) {
            ForEach(speeds, id: \.self) { rate in
                Button {
                    player.setRate(rate)
                } label: {
                    Text("\(rate, specifier: "%g")x")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(player.playbackRate == rate ? Color.accentColor.opacity(0.2) : .clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

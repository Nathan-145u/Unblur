//
//  EpisodeRowView.swift
//  Unblur
//

import SwiftUI

struct EpisodeRowView: View {
    let episode: Episode
    let onTap: () -> Void

    private var downloads: DownloadManager { DownloadManager.shared }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text(AppFormatters.display.string(from: episode.publishDate))
                        Text("·")
                        Text(AppFormatters.duration(episode.duration))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                statusIcon
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if let p = downloads.progress(for: episode.id) {
            ProgressView(value: p).frame(width: 36)
        } else if episode.isDownloaded {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Image(systemName: "arrow.down.circle").foregroundStyle(.secondary)
        }
    }
}

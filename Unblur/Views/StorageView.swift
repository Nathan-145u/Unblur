//
//  StorageView.swift
//  Unblur — v0.4 batch download + storage management
//

import SwiftUI
import SwiftData

struct StorageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.publishDate, order: .reverse) private var episodes: [Episode]

    private var downloads: DownloadManager { DownloadManager.shared }

    var downloaded: [Episode] { episodes.filter { $0.isDownloaded } }
    var notDownloaded: [Episode] { episodes.filter { !$0.isDownloaded } }

    var totalBytes: Int64 {
        downloaded.reduce(0) { sum, ep in
            guard let url = ep.localAudioURL,
                  let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int64
            else { return sum }
            return sum + size
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Disk Usage") {
                    LabeledContent("Episodes downloaded", value: "\(downloaded.count)")
                    LabeledContent("Total size",
                                   value: ByteCountFormatter.string(fromByteCount: totalBytes,
                                                                    countStyle: .file))
                }
                Section("Batch") {
                    Button {
                        batchDownloadLatest(5)
                    } label: {
                        Label("Download latest 5", systemImage: "square.and.arrow.down.on.square")
                    }
                    Button(role: .destructive) {
                        deleteAll()
                    } label: {
                        Label("Delete all downloads", systemImage: "trash")
                    }
                }
                Section("Downloaded") {
                    ForEach(downloaded) { ep in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(ep.title).lineLimit(1)
                                Text(AppFormatters.display.string(from: ep.publishDate))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                deleteFile(ep)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Storage")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func deleteFile(_ ep: Episode) {
        if let url = ep.localAudioURL {
            try? FileManager.default.removeItem(at: url)
        }
        ep.localAudioFilename = nil
        ep.downloadProgress = 0
        try? modelContext.save()
    }

    private func deleteAll() {
        for ep in downloaded { deleteFile(ep) }
    }

    private func batchDownloadLatest(_ n: Int) {
        let targets = notDownloaded.prefix(n)
        for ep in targets {
            let id = ep.id
            downloads.download(episodeID: id, from: ep.remoteAudioURL) { result in
                if case .success(let filename) = result {
                    ep.localAudioFilename = filename
                    ep.downloadProgress = 1.0
                    try? modelContext.save()
                    Task { await TranscriptionService.shared.transcribe(ep, context: modelContext) }
                }
            }
        }
    }
}

//
//  EpisodeListView.swift
//  Unblur
//

import SwiftUI
import SwiftData

struct EpisodeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.publishDate, order: .reverse) private var episodes: [Episode]

    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showFullPlayer = false
    @State private var showSettings = false
    @State private var showStorage = false

    private var player: AudioPlayerManager { AudioPlayerManager.shared }
    private var downloads: DownloadManager { DownloadManager.shared }

    var filtered: [Episode] {
        guard !searchText.isEmpty else { return episodes }
        return episodes.filter { $0.title.range(of: searchText, options: .caseInsensitive) != nil }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    ForEach(filtered) { ep in
                        EpisodeRowView(episode: ep, onTap: { handleTap(ep) })
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search episodes")
                .refreshable { await refresh() }

                if player.currentEpisode != nil {
                    MiniPlayerView(onTap: { showFullPlayer = true })
                        .padding(.bottom, 4)
                }
            }
            .navigationTitle("Unblur")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { showStorage = true } label: { Image(systemName: "internaldrive") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if isRefreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showFullPlayer) { FullPlayerView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showStorage) { StorageView() }
            .task { if episodes.isEmpty { await refresh() } }
        }
    }

    private func handleTap(_ ep: Episode) {
        if ep.isDownloaded {
            player.load(ep)
            player.play()
            showFullPlayer = true
        } else if downloads.progress(for: ep.id) == nil {
            startDownload(ep)
        }
    }

    private func startDownload(_ ep: Episode) {
        let id = ep.id
        downloads.download(episodeID: id, from: ep.remoteAudioURL) { result in
            switch result {
            case .success(let filename):
                ep.localAudioFilename = filename
                ep.downloadProgress = 1.0
                try? modelContext.save()
                // Auto-trigger transcription
                Task { await TranscriptionService.shared.transcribe(ep, context: modelContext) }
            case .failure(let err):
                errorMessage = err.localizedDescription
            }
        }
    }

    @MainActor
    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let feed = try await RSSParser.fetch()
            let existingURLs = Set(episodes.map { $0.remoteAudioURL })
            for parsed in feed.episodes where !existingURLs.contains(parsed.remoteAudioURL) {
                let ep = Episode(
                    title: parsed.title,
                    publishDate: parsed.publishDate,
                    duration: parsed.duration,
                    remoteAudioURL: parsed.remoteAudioURL,
                    artworkURL: parsed.artworkURL ?? feed.channelArtworkURL
                )
                modelContext.insert(ep)
            }
            try? modelContext.save()
        } catch {
            errorMessage = "Failed to refresh feed: \(error.localizedDescription)"
        }
    }
}

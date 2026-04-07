//
//  SubtitleScrollView.swift
//  Unblur — v0.2 sentence subtitles + word highlight; v0.3 bilingual mode
//

import SwiftUI
import SwiftData

enum SubtitleDisplayMode: String, CaseIterable, Identifiable {
    case englishOnly = "EN"
    case bilingual = "EN+中"
    case off = "Off"
    var id: String { rawValue }
}

struct SubtitleScrollView: View {
    let episode: Episode
    @Environment(\.modelContext) private var modelContext
    @State private var displayMode: SubtitleDisplayMode = .englishOnly
    @State private var selectedText: String?
    @State private var showAsk = false

    init(episode: Episode) { self.episode = episode }

    private var player: AudioPlayerManager { AudioPlayerManager.shared }

    var sortedSubs: [Subtitle] {
        episode.subtitles.sorted { $0.index < $1.index }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Mode", selection: $displayMode) {
                    ForEach(SubtitleDisplayMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Menu {
                    Button("Translate all") { translateAll() }
                    Button("Re-transcribe") {
                        Task { await TranscriptionService.shared.transcribe(episode, context: modelContext) }
                    }
                    Divider()
                    Button("Export SRT") { ExportHelper.share(episode: episode, format: .srt) }
                    Button("Export VTT") { ExportHelper.share(episode: episode, format: .vtt) }
                    Button("Export TXT") { ExportHelper.share(episode: episode, format: .txt) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            if episode.transcriptionStatus == "running" {
                ProgressView("Transcribing…")
            } else if episode.transcriptionStatus == "failed" {
                VStack(spacing: 8) {
                    Text("Transcription failed").foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await TranscriptionService.shared.transcribe(episode, context: modelContext) }
                    }
                }
            } else if sortedSubs.isEmpty {
                VStack(spacing: 8) {
                    Text("No subtitles yet").foregroundStyle(.secondary)
                    Button("Transcribe") {
                        Task { await TranscriptionService.shared.transcribe(episode, context: modelContext) }
                    }
                }
            } else if displayMode != .off {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(sortedSubs) { sub in
                                subtitleRow(sub)
                                    .id(sub.id)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .onChange(of: currentSubtitleID) { _, newID in
                        if let id = newID {
                            withAnimation { proxy.scrollTo(id, anchor: .center) }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAsk) {
            if let q = selectedText {
                ChatPanelView(episode: episode, prefilled: q)
            }
        }
    }

    private var currentSubtitleID: UUID? {
        sortedSubs.first(where: { player.currentTime >= $0.startTime && player.currentTime <= $0.endTime })?.id
    }

    @ViewBuilder
    private func subtitleRow(_ sub: Subtitle) -> some View {
        let isCurrent = currentSubtitleID == sub.id
        VStack(alignment: .leading, spacing: 4) {
            highlightedText(sub, isCurrent: isCurrent)
                .font(.body)
                .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
            if displayMode == .bilingual {
                if let zh = sub.translation {
                    Text(zh).font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Translate") {
                        Task {
                            try? await TranslationService.shared.translate(subtitle: sub)
                            try? modelContext.save()
                        }
                    }
                    .font(.caption)
                }
            }
        }
        .padding(8)
        .background(isCurrent ? Color.accentColor.opacity(0.1) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            player.seek(to: sub.startTime)
        }
        .contextMenu {
            Button("Ask Claude about this") {
                selectedText = sub.text
                showAsk = true
            }
            Button("Copy") {
                #if os(iOS)
                UIPasteboard.general.string = sub.text
                #endif
            }
        }
    }

    @ViewBuilder
    private func highlightedText(_ sub: Subtitle, isCurrent: Bool) -> some View {
        if isCurrent, !sub.wordTimings.isEmpty {
            let now = player.currentTime
            sub.wordTimings.reduce(Text("")) { acc, w in
                let active = now >= w.start && now <= w.end
                let piece = Text(w.word + " ")
                    .foregroundColor(active ? .accentColor : .primary)
                    .fontWeight(active ? .bold : .regular)
                return acc + piece
            }
        } else {
            Text(sub.text)
        }
    }

    private func translateAll() {
        Task {
            for sub in sortedSubs where sub.translation == nil {
                try? await TranslationService.shared.translate(subtitle: sub)
            }
            try? modelContext.save()
        }
    }
}

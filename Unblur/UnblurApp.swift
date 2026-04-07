//
//  UnblurApp.swift
//  Unblur
//

import SwiftUI
import SwiftData

@main
struct UnblurApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Episode.self,
            Subtitle.self,
            ChatMessage.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            EpisodeListView()
                .modifier(KeyboardShortcutsModifier())
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                AudioPlayerManager.shared.savePosition()
                let ctx = sharedModelContainer.mainContext
                try? ctx.save()
            }
        }
    }
}

/// v0.4 — global keyboard shortcuts. Adds invisible buttons that only respond to keys.
struct KeyboardShortcutsModifier: ViewModifier {
    private var player: AudioPlayerManager { AudioPlayerManager.shared }

    func body(content: Content) -> some View {
        content.background(
            VStack {
                Button("") { player.togglePlayPause() }
                    .keyboardShortcut(.space, modifiers: [])
                Button("") { player.skip(by: -15) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("") { player.skip(by: 15) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("") { player.setRate(min(2.0, player.playbackRate + 0.25)) }
                    .keyboardShortcut("]", modifiers: [.command])
                Button("") { player.setRate(max(0.5, player.playbackRate - 0.25)) }
                    .keyboardShortcut("[", modifiers: [.command])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }
}

//
//  ChatPanelView.swift
//  Unblur — v0.4 Claude Q&A panel with templates + history
//

import SwiftUI
import SwiftData

struct ChatPanelView: View {
    let episode: Episode
    var prefilled: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allMessages: [ChatMessage]

    @State private var input: String = ""
    @State private var quoted: String?
    @State private var sending = false
    @State private var error: String?

    private let templates: [(label: String, prompt: String)] = [
        ("Explain", "Explain this in plain English for an intermediate learner:"),
        ("Vocabulary", "List the key vocabulary in this and define each word:"),
        ("Grammar", "Explain the grammar of this sentence step by step:"),
        ("Summarize", "Summarize this in 2-3 sentences:")
    ]

    var messages: [ChatMessage] {
        allMessages
            .filter { $0.episodeID == episode.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { m in
                                messageBubble(m).id(m.id)
                            }
                            if let error {
                                Text(error).font(.caption).foregroundStyle(.red)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                Divider()
                templateBar
                inputBar
            }
            .navigationTitle("Ask Claude")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let p = prefilled {
                    quoted = p
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ m: ChatMessage) -> some View {
        let isUser = m.role == "user"
        HStack {
            if isUser { Spacer() }
            VStack(alignment: .leading, spacing: 4) {
                if let q = m.quotedText {
                    Text("“\(q)”").font(.caption2).italic().foregroundStyle(.secondary)
                }
                Text(m.content).font(.body)
            }
            .padding(10)
            .background(isUser ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            if !isUser { Spacer() }
        }
    }

    private var templateBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(templates, id: \.label) { t in
                    Button(t.label) {
                        input = t.prompt
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.gray.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.top, 6)
        }
    }

    private var inputBar: some View {
        VStack(spacing: 4) {
            if let q = quoted {
                HStack {
                    Text("“\(q)”").font(.caption).italic().lineLimit(2)
                    Spacer()
                    Button { quoted = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
            HStack {
                TextField("Ask about this episode…", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                Button {
                    Task { await send() }
                } label: {
                    if sending { ProgressView() }
                    else { Image(systemName: "paperplane.fill") }
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || sending)
            }
            .padding()
        }
    }

    @MainActor
    private func send() async {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        let userMsg = ChatMessage(
            episodeID: episode.id,
            role: "user",
            content: prompt,
            quotedText: quoted
        )
        modelContext.insert(userMsg)
        try? modelContext.save()
        input = ""
        sending = true
        defer { sending = false }

        let composed = quoted.map { "Quoted: \"\($0)\"\n\nQuestion: \(prompt)" } ?? prompt
        quoted = nil

        let history = messages.suffix(20).map {
            ClaudeMessage(role: $0.role, content: $0.content)
        }
        var msgs = history
        // Replace last user msg with composed (with quote context)
        if let lastIdx = msgs.lastIndex(where: { $0.role == "user" }) {
            msgs[lastIdx] = ClaudeMessage(role: "user", content: composed)
        }

        do {
            let reply = try await ClaudeClient.shared.complete(
                system: "You are a helpful English-learning assistant for podcast listeners. Be concise and clear.",
                messages: msgs
            )
            let asst = ChatMessage(
                episodeID: episode.id,
                role: "assistant",
                content: reply
            )
            modelContext.insert(asst)
            try? modelContext.save()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

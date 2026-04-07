//
//  TranslationService.swift
//  Unblur — v0.3 sentence-by-sentence Chinese translation
//

import Foundation

@MainActor
final class TranslationService {
    static let shared = TranslationService()

    private let system = """
    You are a precise translator. Translate the user's English sentence into Simplified Chinese.
    Output ONLY the translation, no commentary, no quotes.
    """

    func translate(text: String) async throws -> String {
        let result = try await ClaudeClient.shared.complete(
            system: system,
            messages: [ClaudeMessage(role: "user", content: text)],
            maxTokens: 512
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func translate(subtitle: Subtitle) async throws {
        let zh = try await translate(text: subtitle.text)
        subtitle.translation = zh
    }
}

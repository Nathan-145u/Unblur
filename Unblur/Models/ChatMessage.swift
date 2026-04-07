//
//  ChatMessage.swift
//  Unblur — v0.4 chat history persistence
//

import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var episodeID: UUID
    var role: String  // "user" | "assistant"
    var content: String
    var createdAt: Date
    /// Optional quoted subtitle text the user selected.
    var quotedText: String?

    init(
        id: UUID = UUID(),
        episodeID: UUID,
        role: String,
        content: String,
        createdAt: Date = .now,
        quotedText: String? = nil
    ) {
        self.id = id
        self.episodeID = episodeID
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.quotedText = quotedText
    }
}

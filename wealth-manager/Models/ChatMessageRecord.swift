import Foundation
import SwiftData

/// A persisted chat message from the AI Advisor conversation.
@Model
final class ChatMessageRecord {
    var id: UUID
    var role: String          // "user" | "assistant"
    var content: String
    var conversationId: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        conversationId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.conversationId = conversationId
        self.createdAt = createdAt
    }
}

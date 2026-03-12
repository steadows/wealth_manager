import Foundation

/// A lightweight value type for displaying chat messages in the UI.
/// Separate from the persisted `ChatMessageRecord` @Model.
struct ChatDisplayMessage: Identifiable {
    let id: UUID
    let role: String   // "user" | "assistant"
    let content: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }

    /// Creates a display message from a persisted ChatMessageRecord.
    init(record: ChatMessageRecord) {
        self.id = record.id
        self.role = record.role
        self.content = record.content
        self.createdAt = record.createdAt
    }
}

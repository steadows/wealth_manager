import Foundation
import Observation
import SwiftData

/// ViewModel for the AI Advisor chat interface.
@Observable
final class AdvisorChatViewModel {

    // MARK: - State

    /// Display messages (plain structs, safe to access from any context).
    var messages: [ChatDisplayMessage] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var inputText: String = ""

    // MARK: - Private

    private let advisoryService: AdvisoryServiceProtocol
    private let modelContext: ModelContext
    /// Stable conversation ID for this session. Persisted so loadHistory can filter.
    private let conversationId: UUID

    // MARK: - Init

    init(
        advisoryService: AdvisoryServiceProtocol,
        modelContext: ModelContext,
        conversationId: UUID = UUID()
    ) {
        self.advisoryService = advisoryService
        self.modelContext = modelContext
        self.conversationId = conversationId
    }

    // MARK: - Actions

    /// Loads persisted history for this conversation from SwiftData.
    func loadHistory() async {
        let id = conversationId
        var descriptor = FetchDescriptor<ChatMessageRecord>(
            predicate: #Predicate { $0.conversationId == id },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.fetchLimit = 200
        let records = (try? modelContext.fetch(descriptor)) ?? []
        messages = records.map { ChatDisplayMessage(record: $0) }
    }

    /// Sends a message and streams the assistant response.
    /// Guards against concurrent invocations via `isLoading`.
    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        inputText = ""
        isLoading = true
        errorMessage = nil

        let userDisplay = ChatDisplayMessage(role: "user", content: trimmed)
        messages.append(userDisplay)
        persistMessage(role: "user", content: trimmed, id: userDisplay.id)

        // Create a placeholder assistant message that updates as chunks arrive
        let assistantId = UUID()
        let placeholder = ChatDisplayMessage(role: "assistant", content: "")
        messages.append(placeholder)
        var accumulated = ""

        do {
            let stream = advisoryService.streamChat(message: trimmed, conversationId: conversationId)
            for try await chunk in stream {
                accumulated += chunk
                // Replace the last message with updated content
                let updated = ChatDisplayMessage(id: assistantId, role: "assistant", content: accumulated)
                messages[messages.count - 1] = updated
            }

            // Persist the final complete message
            persistMessage(role: "assistant", content: accumulated, id: assistantId)
            try modelContext.save()
        } catch {
            // Remove the placeholder if streaming failed with no content
            if accumulated.isEmpty {
                messages.removeLast()
            }
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Private

    private func persistMessage(role: String, content: String, id: UUID) {
        let record = ChatMessageRecord(
            id: id,
            role: role,
            content: content,
            conversationId: conversationId
        )
        modelContext.insert(record)
    }
}

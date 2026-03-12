import Testing
import Foundation
import SwiftData
import Observation

@testable import wealth_manager

// MARK: - AdvisorChatViewModelTests

@Suite("AdvisorChatViewModel", .serialized)
struct AdvisorChatViewModelTests {

    // MARK: - Helpers

    /// In-memory ModelContainer with ChatMessageRecord schema.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: ChatMessageRecord.self, configurations: config)
    }

    private func makeVM(
        service: MockAdvisoryService = MockAdvisoryService(),
        container: ModelContainer? = nil
    ) throws -> AdvisorChatViewModel {
        let c = try container ?? makeContainer()
        // Use ModelContext(container) — no @MainActor requirement
        let ctx = ModelContext(c)
        return AdvisorChatViewModel(advisoryService: service, modelContext: ctx)
    }

    // MARK: - sendMessage

    @Test("sendMessage: appends user message immediately")
    func sendMessageAppendsUserMessage() async throws {
        let service = MockAdvisoryService()
        service.stubbedChatChunks = ["Hello back!"]
        let vm = try makeVM(service: service)

        await vm.sendMessage("Hello advisor")

        // vm.messages are ChatDisplayMessage (plain struct — no actor isolation)
        let userMessages = vm.messages.filter { $0.role == "user" }
        #expect(userMessages.count == 1)
        #expect(userMessages.first?.content == "Hello advisor")
    }

    @Test("sendMessage: appends assistant response after stream")
    func sendMessageAppendsAssistantResponse() async throws {
        let service = MockAdvisoryService()
        service.stubbedChatChunks = ["Great ", "question!"]
        let vm = try makeVM(service: service)

        await vm.sendMessage("What should I invest in?")

        let assistantMessages = vm.messages.filter { $0.role == "assistant" }
        #expect(assistantMessages.count == 1)
        #expect(assistantMessages.first?.content == "Great question!")
    }

    @Test("sendMessage: sets errorMessage on network failure")
    func sendMessageSetsErrorOnFailure() async throws {
        let service = MockAdvisoryService()
        service.shouldThrow = APIError.noData
        let vm = try makeVM(service: service)

        await vm.sendMessage("Will I retire early?")

        #expect(vm.errorMessage != nil)
    }

    @Test("sendMessage: isLoading is false after completion")
    func sendMessageIsLoadingFalseAfter() async throws {
        let service = MockAdvisoryService()
        service.stubbedChatChunks = ["Done"]
        let vm = try makeVM(service: service)

        await vm.sendMessage("Test")

        #expect(!vm.isLoading)
    }

    @Test("sendMessage: persists both messages to SwiftData")
    func sendMessagePersistsMessages() async throws {
        let container = try makeContainer()
        let service = MockAdvisoryService()
        service.stubbedChatChunks = ["Saved response"]
        let vm = try makeVM(service: service, container: container)

        await vm.sendMessage("Persist me")

        // Use a new ModelContext on the same container to verify persistence
        let verifyCtx = ModelContext(container)
        let descriptor = FetchDescriptor<ChatMessageRecord>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let saved = try verifyCtx.fetch(descriptor)
        #expect(saved.count == 2)
        #expect(saved.first?.role == "user")
        #expect(saved.last?.role == "assistant")
    }

    @Test("sendMessage: clears inputText after sending")
    func sendMessageClearsInput() async throws {
        let service = MockAdvisoryService()
        service.stubbedChatChunks = ["OK"]
        let vm = try makeVM(service: service)
        vm.inputText = "A question"

        await vm.sendMessage(vm.inputText)

        #expect(vm.inputText.isEmpty)
    }

    @Test("sendMessage: does nothing if message is empty")
    func sendMessageIgnoresEmpty() async throws {
        let service = MockAdvisoryService()
        let vm = try makeVM(service: service)

        await vm.sendMessage("")

        #expect(vm.messages.isEmpty)
        #expect(!vm.isLoading)
    }
}

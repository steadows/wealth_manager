import SwiftUI
import SwiftData

// MARK: - AdvisorChatView

/// Full-screen chat interface for the AI financial advisor.
struct AdvisorChatView: View {
    @State var viewModel: AdvisorChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
            Divider().overlay(WMColors.glassBorder)
            inputBar
        }
        .background(WMColors.background)
        .task { await viewModel.loadHistory() }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundStyle(WMColors.primary)
            Text("AI Advisor")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Spacer()
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(WMColors.glassBg)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) {
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask your advisor...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(WMColors.glassBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onSubmit { sendIfNotEmpty() }

            Button(action: sendIfNotEmpty) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? WMColors.textMuted
                            : WMColors.primary
                    )
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      || viewModel.isLoading)
            .buttonStyle(.plain)
            .accessibilityLabel("Send message")
            .accessibilityHint("Double tap to send your message to the AI advisor")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(WMColors.background)
    }

    private func sendIfNotEmpty() {
        let text = viewModel.inputText
        Task { await viewModel.sendMessage(text) }
    }
}

// MARK: - ChatBubble

private struct ChatBubble: View {
    let message: ChatDisplayMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }
            Text(message.content)
                .font(WMTypography.body)
                .foregroundStyle(isUser ? .white : WMColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? WMColors.primary : WMColors.glassBg)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if !isUser { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUser ? "You" : "Advisor"): \(message.content)")
    }
}

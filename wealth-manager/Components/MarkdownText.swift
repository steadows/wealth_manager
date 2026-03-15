import SwiftUI

/// Parsed block types from markdown text.
private enum MarkdownBlock {
    case heading2(String)
    case heading3(String)
    case divider
    case bullet(String)
    case paragraph(String)
}

/// A reusable markdown text renderer for Claude AI responses.
///
/// Handles headings, dividers, bullets, and inline markdown (bold, italic, code).
/// Consecutive plain-text lines are collapsed into a single paragraph.
struct MarkdownText: View {
    let text: String
    var bodyFont: Font = WMTypography.body
    var headingFont: Font = WMTypography.subheading
    var bodyColor: Color = WMColors.textPrimary
    var mutedColor: Color = WMColors.textMuted

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    // MARK: - Parsing

    private var blocks: [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        var pendingParagraph: [String] = []

        func flushParagraph() {
            if !pendingParagraph.isEmpty {
                result.append(.paragraph(pendingParagraph.joined(separator: " ")))
                pendingParagraph.removeAll()
            }
        }

        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                flushParagraph()
                result.append(.heading2(String(line.dropFirst(3))))
            } else if line.hasPrefix("### ") {
                flushParagraph()
                result.append(.heading3(String(line.dropFirst(4))))
            } else if line.range(of: #"^[-*]{3,}$"#, options: .regularExpression) != nil {
                flushParagraph()
                result.append(.divider)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                result.append(.bullet(String(line.dropFirst(2))))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraph()
            } else {
                pendingParagraph.append(line)
            }
        }
        flushParagraph()
        return result
    }

    // MARK: - Rendering

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading2(let content):
            Text(content)
                .font(headingFont)
                .foregroundStyle(bodyColor)
        case .heading3(let content):
            Text(content)
                .font(bodyFont.bold())
                .foregroundStyle(bodyColor)
        case .divider:
            Divider()
                .overlay(WMColors.glassBorder)
        case .bullet(let content):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(WMColors.secondary)
                    .frame(width: 6, height: 6)
                inlineMarkdown(content)
            }
        case .paragraph(let content):
            inlineMarkdown(content)
        }
    }

    /// Renders inline text with bold support by splitting on `**` markers.
    /// More reliable than AttributedString(markdown:) for Claude's streaming output,
    /// which often places `**` directly adjacent to surrounding words.
    private func inlineMarkdown(_ content: String) -> some View {
        let parts = content.components(separatedBy: "**")
        var attributed = AttributedString()
        for (index, part) in parts.enumerated() {
            guard !part.isEmpty else { continue }
            var segment = AttributedString(part)
            // Odd-indexed segments are between ** pairs → bold
            if index % 2 == 1 {
                segment.inlinePresentationIntent = .stronglyEmphasized
            }
            attributed.append(segment)
        }
        return Text(attributed)
            .font(bodyFont)
            .foregroundStyle(bodyColor)
    }
}

#Preview {
    MarkdownText(text: """
    ## Portfolio Summary
    Your portfolio is **well-diversified** across *multiple* asset classes.
    ---
    ### Key Highlights
    - Equity allocation is `65%` of total
    - Fixed income provides **stability**
    - Consider rebalancing in Q2
    """)
    .padding()
    .background(.black)
}

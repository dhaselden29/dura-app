import SwiftUI

// MARK: - Environment Key

/// Indicates whether block views are being rendered in read-only preview mode.
struct IsBlockPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isBlockPreview: Bool {
        get { self[IsBlockPreviewKey.self] }
        set { self[IsBlockPreviewKey.self] = newValue }
    }
}

// MARK: - MarkdownText

/// Renders inline markdown (bold, italic, links, code, strikethrough) using
/// SwiftUI's `AttributedString(markdown:)`. Falls back to plain text on failure.
struct MarkdownText: View {
    let text: String
    var font: Font = .body

    var body: some View {
        rendered
            .font(font)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    private var rendered: Text {
        guard let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return Text(text)
        }
        return Text(attributed)
    }
}

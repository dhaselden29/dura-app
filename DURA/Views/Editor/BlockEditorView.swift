import SwiftUI

/// The editor container. Default mode uses a native text view for natural markdown
/// editing; toggle mode shows a rich block-based preview (read-only).
struct BlockEditorView: View {
    @Binding var markdown: String
    @State private var editorMode: EditorMode = .markdown
    @State private var formatAction: FormatAction?

    private enum EditorMode: String, CaseIterable {
        case markdown = "Markdown"
        case richText = "Rich Text"
    }

    private var showPreview: Bool { editorMode == .richText }

    var body: some View {
        VStack(spacing: 0) {
            if showPreview {
                previewMode
            } else {
                MarkdownTextView(text: $markdown, formatAction: $formatAction)
            }

            editorToolbar
        }
    }

    // MARK: - Preview Mode (read-only block rendering)

    private var previewMode: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(BlockParser.parse(markdown)) { block in
                    BlockRowView(
                        block: .constant(block),
                        isSelected: false,
                        onTap: {},
                        onContentChange: { _ in },
                        onDelete: {},
                        onReturn: {},
                        attachments: nil
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .environment(\.isBlockPreview, true)
    }

    // MARK: - Toolbar

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            Picker("Mode", selection: $editorMode) {
                ForEach(EditorMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            if !showPreview {
                Divider()
                    .frame(height: 16)

                formatButton(icon: "bold", tooltip: "Bold (Cmd+B)") {
                    formatAction = .bold
                }
                formatButton(icon: "italic", tooltip: "Italic (Cmd+I)") {
                    formatAction = .italic
                }
                formatButton(icon: "strikethrough", tooltip: "Strikethrough (Cmd+Shift+X)") {
                    formatAction = .strikethrough
                }
                formatButton(icon: "chevron.left.forwardslash.chevron.right", tooltip: "Code (Cmd+E)") {
                    formatAction = .inlineCode
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    private func formatButton(icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

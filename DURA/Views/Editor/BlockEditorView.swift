import SwiftUI

/// The editor container. Default mode uses a native text view for natural markdown
/// editing; toggle mode shows a rich block-based preview (read-only).
struct BlockEditorView: View {
    @Binding var markdown: String
    @State private var showPreview = false
    @State private var formatAction: FormatAction?

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
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(BlockParser.parse(markdown)) { block in
                    BlockRowView(
                        block: .constant(block),
                        isSelected: false,
                        onTap: {},
                        onContentChange: { _ in },
                        onDelete: {},
                        onReturn: {}
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Toolbar

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            // Preview toggle
            Button {
                showPreview.toggle()
            } label: {
                Image(systemName: showPreview ? "pencil" : "eye")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .help(showPreview ? "Edit Markdown" : "Preview")

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

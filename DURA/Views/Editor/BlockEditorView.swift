import SwiftUI

/// The editor container. Both modes are editable:
/// - **Rich Text** uses a proportional font for comfortable reading/writing.
/// - **Markdown** uses a monospaced font for precise markdown editing.
struct BlockEditorView: View {
    @Binding var markdown: String
    @Binding var requestFocus: Bool
    @State private var editorMode: EditorMode = .richText
    @State private var formatAction: FormatAction?

    private enum EditorMode: String, CaseIterable {
        case markdown = "Markdown"
        case richText = "Rich Text"
    }

    var body: some View {
        VStack(spacing: 0) {
            MarkdownTextView(
                text: $markdown,
                formatAction: $formatAction,
                requestFocus: $requestFocus,
                useProportionalFont: editorMode == .richText
            )

            editorToolbar
        }
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

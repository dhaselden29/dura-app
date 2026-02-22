import SwiftUI

/// The editor container. Both modes are editable:
/// - **Rich Text** uses a proportional font for comfortable reading/writing.
/// - **Markdown** uses a monospaced font for precise markdown editing.
struct BlockEditorView: View {
    @Binding var markdown: String
    @Binding var requestFocus: Bool
    var isReadOnly: Bool = false
    var highlights: [Highlight] = []
    var onHighlightCreated: ((Highlight) -> Void)?
    var onAnnotationRequest: ((String, Int, Int) -> Void)?
    var focusedHighlightID: UUID?
    var onScrollProgressChanged: ((Double) -> Void)?

    @State private var editorMode: EditorMode = .richText
    @State private var formatAction: FormatAction?

    @AppStorage("readerFontSize") private var fontSize: Double = ReaderDefaults.fontSize
    @AppStorage("readerLineSpacing") private var lineSpacing: Double = ReaderDefaults.lineSpacing
    @AppStorage("readerMaxWidth") private var maxWidth: Double = ReaderDefaults.maxWidth
    @AppStorage("readerTheme") private var themeRaw: String = ReaderDefaults.theme
    @AppStorage("readerFont") private var fontFamilyRaw: String = ReaderDefaults.font

    private var theme: ReaderTheme {
        ReaderTheme(rawValue: themeRaw) ?? .light
    }

    private var fontFamily: ReaderFont {
        ReaderFont(rawValue: fontFamilyRaw) ?? .system
    }

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
                isReadOnly: isReadOnly,
                useProportionalFont: editorMode == .richText,
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                fontFamily: fontFamily,
                maxWidth: maxWidth,
                theme: theme,
                highlights: highlights,
                onHighlightCreated: onHighlightCreated,
                onAnnotationRequest: onAnnotationRequest,
                focusedHighlightID: focusedHighlightID,
                onScrollProgressChanged: onScrollProgressChanged
            )

            if !isReadOnly {
                editorToolbar
            }
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

            Divider()
                .frame(height: 16)

            // Font size stepper
            HStack(spacing: 4) {
                Button {
                    fontSize = max(12, fontSize - 1)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Decrease font size")

                Text("\(Int(fontSize))")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(minWidth: 20)

                Button {
                    fontSize = min(28, fontSize + 1)
                } label: {
                    Image(systemName: "textformat.size.larger")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Increase font size")
            }

            // Line spacing stepper
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    lineSpacing = max(0, lineSpacing - 2)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .help("Decrease line spacing")

                Button {
                    lineSpacing = min(12, lineSpacing + 2)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .help("Increase line spacing")
            }

            // Theme picker
            Picker("", selection: $themeRaw) {
                ForEach(ReaderTheme.allCases, id: \.rawValue) { t in
                    Label(t.displayName, systemImage: t.iconName)
                        .tag(t.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
            .help("Reader theme")

            // Font picker
            Menu {
                ForEach(ReaderFont.allCases, id: \.rawValue) { f in
                    Button {
                        fontFamilyRaw = f.rawValue
                    } label: {
                        HStack {
                            Text(f.displayName)
                            if fontFamilyRaw == f.rawValue {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "textformat")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
            .help("Font family")

            // Width toggle
            Button {
                if maxWidth < 10000 {
                    maxWidth = 100000
                } else {
                    maxWidth = 700
                }
            } label: {
                Image(systemName: maxWidth < 10000 ? "arrow.left.and.right" : "arrow.right.and.line.vertical.and.arrow.left")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help(maxWidth < 10000 ? "Full width" : "Constrain width")

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

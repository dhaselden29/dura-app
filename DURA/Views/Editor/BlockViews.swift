import SwiftUI

// MARK: - Block Row (Dispatcher)

/// Routes a single Block to the correct type-specific view.
struct BlockRowView: View {
    @Binding var block: Block
    let isSelected: Bool
    let onTap: () -> Void
    let onContentChange: (String) -> Void
    let onDelete: () -> Void
    let onReturn: () -> Void

    @Environment(\.isBlockPreview) private var isBlockPreview

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            if !isBlockPreview {
                // Drag handle (visible on hover via parent)
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                    .frame(width: 16)
                    .padding(.top, topPaddingForType)
            }

            blockContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var blockContent: some View {
        switch block.type {
        case .paragraph:
            ParagraphBlockView(
                text: $block.content,
                isSelected: isSelected,
                onReturn: onReturn
            )

        case .heading(let level):
            HeadingBlockView(
                text: $block.content,
                level: level,
                isSelected: isSelected,
                onReturn: onReturn
            )

        case .bulletList:
            BulletListBlockView(
                text: $block.content,
                isSelected: isSelected
            )

        case .numberedList:
            NumberedListBlockView(
                text: $block.content,
                isSelected: isSelected
            )

        case .checklist:
            ChecklistBlockView(
                text: $block.content,
                metadata: $block.metadata,
                isSelected: isSelected
            )

        case .quote:
            QuoteBlockView(
                text: $block.content,
                isSelected: isSelected
            )

        case .codeBlock:
            CodeBlockView(
                text: $block.content,
                language: block.metadata?["language"] ?? "",
                isSelected: isSelected
            )

        case .divider:
            DividerBlockView()

        case .image:
            ImageBlockView(
                alt: block.content,
                url: block.metadata?["url"] ?? ""
            )

        case .toggle:
            ToggleBlockView(
                summary: block.metadata?["summary"] ?? "Details",
                content: $block.content,
                isSelected: isSelected
            )

        case .embed:
            EmbedBlockView(url: block.metadata?["url"] ?? block.content)

        case .audio:
            AudioBlockView(
                filename: block.metadata?["filename"] ?? "Audio",
                url: block.content
            )
        }
    }

    private var topPaddingForType: CGFloat {
        switch block.type {
        case .heading: 4
        case .divider: 8
        default: 6
        }
    }
}

// MARK: - Paragraph

struct ParagraphBlockView: View {
    @Binding var text: String
    let isSelected: Bool
    let onReturn: () -> Void

    @Environment(\.isBlockPreview) private var isBlockPreview

    var body: some View {
        if isBlockPreview {
            MarkdownText(text: text)
                .padding(.vertical, 4)
        } else {
            BlockTextField(
                text: $text,
                placeholder: "Type something...",
                font: .body,
                isSelected: isSelected,
                onReturn: onReturn
            )
        }
    }
}

// MARK: - Heading

struct HeadingBlockView: View {
    @Binding var text: String
    let level: Int
    let isSelected: Bool
    let onReturn: () -> Void

    @Environment(\.isBlockPreview) private var isBlockPreview

    private var font: Font {
        switch level {
        case 1: .system(size: 28, weight: .bold)
        case 2: .system(size: 24, weight: .bold)
        case 3: .system(size: 20, weight: .semibold)
        case 4: .system(size: 18, weight: .semibold)
        case 5: .system(size: 16, weight: .medium)
        case 6: .system(size: 14, weight: .medium)
        default: .headline
        }
    }

    var body: some View {
        if isBlockPreview {
            MarkdownText(text: text, font: font)
                .padding(.vertical, 4)
        } else {
            BlockTextField(
                text: $text,
                placeholder: "Heading \(level)",
                font: font,
                isSelected: isSelected,
                onReturn: onReturn
            )
        }
    }
}

// MARK: - Bullet List

struct BulletListBlockView: View {
    @Binding var text: String
    let isSelected: Bool

    private var items: [String] {
        text.components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 6) {
                    Text("\u{2022}")
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                    MarkdownText(text: item)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Numbered List

struct NumberedListBlockView: View {
    @Binding var text: String
    let isSelected: Bool

    private var items: [String] {
        text.components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .padding(.top, 2)

                    MarkdownText(text: item)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Checklist

struct ChecklistBlockView: View {
    @Binding var text: String
    @Binding var metadata: [String: String]?
    let isSelected: Bool

    private var items: [String] {
        text.components(separatedBy: "\n")
    }

    private var checkedIndices: Set<Int> {
        let raw = metadata?["checked"] ?? ""
        guard !raw.isEmpty else { return [] }
        return Set(raw.components(separatedBy: ",").compactMap(Int.init))
    }

    private func toggleItem(at index: Int) {
        var checked = checkedIndices
        if checked.contains(index) {
            checked.remove(index)
        } else {
            checked.insert(index)
        }
        if checked.isEmpty {
            metadata?.removeValue(forKey: "checked")
            if metadata?.isEmpty == true { metadata = nil }
        } else {
            if metadata == nil { metadata = [:] }
            metadata?["checked"] = checked.sorted().map(String.init).joined(separator: ",")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 6) {
                    Button {
                        toggleItem(at: index)
                    } label: {
                        Image(systemName: checkedIndices.contains(index) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(checkedIndices.contains(index) ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)

                    MarkdownText(text: item)
                        .strikethrough(checkedIndices.contains(index))
                        .foregroundStyle(checkedIndices.contains(index) ? .secondary : .primary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Blockquote

struct QuoteBlockView: View {
    @Binding var text: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(.tint)
                .frame(width: 3)

            MarkdownText(text: text, font: .body.italic())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Code Block

struct CodeBlockView: View {
    @Binding var text: String
    let language: String
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !language.isEmpty {
                Text(language)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.vertical, 4)
    }
}

// MARK: - Divider

struct DividerBlockView: View {
    var body: some View {
        Divider()
            .padding(.vertical, 12)
    }
}

// MARK: - Image

struct ImageBlockView: View {
    let alt: String
    let url: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        ProgressView()
                            .frame(height: 120)
                    @unknown default:
                        imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }

            if !alt.isEmpty {
                Text(alt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var imagePlaceholder: some View {
        HStack {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
            Text(alt.isEmpty ? url : alt)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(.fill.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Toggle

struct ToggleBlockView: View {
    let summary: String
    @Binding var content: String
    let isSelected: Bool

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(content)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
        } label: {
            Text(summary)
                .font(.body.weight(.medium))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Embed

struct EmbedBlockView: View {
    let url: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .foregroundStyle(.tint)
            Text(url)
                .font(.body)
                .foregroundStyle(.tint)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.vertical, 4)
    }
}

// MARK: - Audio

struct AudioBlockView: View {
    let filename: String
    let url: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .foregroundStyle(.tint)
            Text(filename)
                .font(.body)
            Spacer()
            Image(systemName: "play.circle")
                .font(.title3)
                .foregroundStyle(.tint)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.vertical, 4)
    }
}

// MARK: - Reusable Block Text Field

/// A text field used within editable blocks. Wraps TextField for single-line editing.
struct BlockTextField: View {
    @Binding var text: String
    let placeholder: String
    let font: Font
    let isSelected: Bool
    let onReturn: () -> Void

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(font)
            .textFieldStyle(.plain)
            .padding(.vertical, 4)
            .onSubmit {
                onReturn()
            }
    }
}

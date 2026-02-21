import Foundation

/// Bidirectional parser: Markdown string ↔ [Block] array.
/// Markdown is always the source of truth. Blocks are a derived representation.
struct BlockParser {

    // MARK: - Markdown → Blocks

    /// Parse a Markdown string into an array of Block values.
    static func parse(_ markdown: String) -> [Block] {
        guard !markdown.isEmpty else {
            return [Block(type: .paragraph, content: "")]
        }

        var blocks: [Block] = []
        let lines = markdown.components(separatedBy: "\n")
        var index = 0

        while index < lines.count {
            let line = lines[index]

            // Fenced code block (``` or ~~~)
            if let codeResult = parseFencedCodeBlock(lines: lines, startIndex: index) {
                blocks.append(codeResult.block)
                index = codeResult.nextIndex
                continue
            }

            // Divider (---, ***, ___)
            if isDivider(line) {
                blocks.append(Block(type: .divider, content: ""))
                index += 1
                continue
            }

            // Heading (# ... ######)
            if let headingBlock = parseHeading(line) {
                blocks.append(headingBlock)
                index += 1
                continue
            }

            // Image (![alt](url))
            if let imageBlock = parseImage(line) {
                blocks.append(imageBlock)
                index += 1
                continue
            }

            // Audio (🔊 [filename](url))
            if let audioBlock = parseAudio(line) {
                blocks.append(audioBlock)
                index += 1
                continue
            }

            // Checklist (- [ ] or - [x])
            if isChecklistItem(line) {
                let result = parseChecklist(lines: lines, startIndex: index)
                blocks.append(result.block)
                index = result.nextIndex
                continue
            }

            // Bullet list (- or * or + at start)
            if isBulletListItem(line) {
                let result = parseBulletList(lines: lines, startIndex: index)
                blocks.append(result.block)
                index = result.nextIndex
                continue
            }

            // Numbered list (1. 2. etc.)
            if isNumberedListItem(line) {
                let result = parseNumberedList(lines: lines, startIndex: index)
                blocks.append(result.block)
                index = result.nextIndex
                continue
            }

            // Blockquote (> ...)
            if line.hasPrefix(">") {
                let result = parseBlockquote(lines: lines, startIndex: index)
                blocks.append(result.block)
                index = result.nextIndex
                continue
            }

            // Empty line — skip (paragraph breaks)
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            // Default: paragraph (collect consecutive non-empty, non-special lines)
            let result = parseParagraph(lines: lines, startIndex: index)
            blocks.append(result.block)
            index = result.nextIndex
        }

        if blocks.isEmpty {
            blocks.append(Block(type: .paragraph, content: ""))
        }

        return blocks
    }

    // MARK: - Blocks → Markdown

    /// Convert an array of Blocks back to a Markdown string.
    static func render(_ blocks: [Block]) -> String {
        blocks.map { renderBlock($0) }.joined(separator: "\n\n")
    }

    private static func renderBlock(_ block: Block) -> String {
        switch block.type {
        case .paragraph:
            return block.content

        case .heading(let level):
            let prefix = String(repeating: "#", count: min(max(level, 1), 6))
            return "\(prefix) \(block.content)"

        case .image:
            let alt = block.content
            let url = block.metadata?["url"] ?? ""
            return "![\(alt)](\(url))"

        case .codeBlock:
            let language = block.metadata?["language"] ?? ""
            return "```\(language)\n\(block.content)\n```"

        case .quote:
            let lines = block.content.components(separatedBy: "\n")
            return lines.map { "> \($0)" }.joined(separator: "\n")

        case .bulletList:
            let items = block.content.components(separatedBy: "\n")
            return items.map { "- \($0)" }.joined(separator: "\n")

        case .numberedList:
            let items = block.content.components(separatedBy: "\n")
            return items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        case .checklist:
            let items = block.content.components(separatedBy: "\n")
            let checks = block.metadata?["checked"]?.components(separatedBy: ",") ?? []
            return items.enumerated().map { idx, item in
                let isChecked = checks.contains(String(idx))
                return "- [\(isChecked ? "x" : " ")] \(item)"
            }.joined(separator: "\n")

        case .divider:
            return "---"

        case .toggle:
            // Render as HTML details/summary for Markdown compatibility
            let summary = block.metadata?["summary"] ?? "Details"
            return "<details>\n<summary>\(summary)</summary>\n\n\(block.content)\n</details>"

        case .embed:
            let url = block.metadata?["url"] ?? block.content
            return url

        case .audio:
            let filename = block.metadata?["filename"] ?? "audio"
            return "🔊 [\(filename)](\(block.content))"
        }
    }

    // MARK: - Line Parsers

    private static func parseHeading(_ line: String) -> Block? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }

        var level = 0
        for char in trimmed {
            if char == "#" { level += 1 }
            else { break }
        }

        guard level >= 1, level <= 6 else { return nil }

        let startIndex = trimmed.index(trimmed.startIndex, offsetBy: level)
        let content = String(trimmed[startIndex...]).trimmingCharacters(in: .whitespaces)

        // Must have a space after #s (or be just #s with no content)
        let afterHashes = String(trimmed[startIndex...])
        guard afterHashes.isEmpty || afterHashes.hasPrefix(" ") else { return nil }

        return Block(type: .heading(level: level), content: content)
    }

    private static func parseImage(_ line: String) -> Block? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Match ![alt](url)
        let pattern = /^!\[([^\]]*)\]\(([^)]+)\)$/
        guard let match = trimmed.firstMatch(of: pattern) else { return nil }

        let alt = String(match.output.1)
        let url = String(match.output.2)
        return Block(type: .image, content: alt, metadata: ["url": url])
    }

    private static func parseAudio(_ line: String) -> Block? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Match 🔊 [filename](url)
        let pattern = /^🔊\s*\[([^\]]+)\]\(([^)]+)\)$/
        guard let match = trimmed.firstMatch(of: pattern) else { return nil }

        let filename = String(match.output.1)
        let url = String(match.output.2)
        return Block(type: .audio, content: url, metadata: ["filename": filename])
    }

    private static func isDivider(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 3 { return false }
        let chars = Set(trimmed)
        return (chars == ["-"] || chars == ["*"] || chars == ["_"]) && trimmed.count >= 3
    }

    private static func isChecklistItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ")
    }

    private static func isBulletListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return (trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ "))
            && !isChecklistItem(line)
    }

    private static func isNumberedListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let pattern = /^\d+\.\s/
        return trimmed.firstMatch(of: pattern) != nil
    }

    // MARK: - Multi-line Parsers

    private struct ParseResult {
        let block: Block
        let nextIndex: Int
    }

    private static func parseFencedCodeBlock(lines: [String], startIndex: Int) -> ParseResult? {
        let line = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("```") || line.hasPrefix("~~~") else { return nil }

        let fence = String(line.prefix(3))
        let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)

        var codeLines: [String] = []
        var idx = startIndex + 1

        while idx < lines.count {
            let currentLine = lines[idx]
            if currentLine.trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                idx += 1
                break
            }
            codeLines.append(currentLine)
            idx += 1
        }

        let content = codeLines.joined(separator: "\n")
        var metadata: [String: String]? = nil
        if !language.isEmpty {
            metadata = ["language": language]
        }

        return ParseResult(
            block: Block(type: .codeBlock, content: content, metadata: metadata),
            nextIndex: idx
        )
    }

    private static func parseBlockquote(lines: [String], startIndex: Int) -> ParseResult {
        var quoteLines: [String] = []
        var idx = startIndex

        while idx < lines.count {
            let line = lines[idx]
            if line.hasPrefix(">") {
                var content = String(line.dropFirst())
                if content.hasPrefix(" ") { content = String(content.dropFirst()) }
                quoteLines.append(content)
                idx += 1
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty && idx + 1 < lines.count && lines[idx + 1].hasPrefix(">") {
                // Allow blank lines within blockquote if next line is also a quote
                quoteLines.append("")
                idx += 1
            } else {
                break
            }
        }

        return ParseResult(
            block: Block(type: .quote, content: quoteLines.joined(separator: "\n")),
            nextIndex: idx
        )
    }

    private static func parseBulletList(lines: [String], startIndex: Int) -> ParseResult {
        var items: [String] = []
        var idx = startIndex

        while idx < lines.count && isBulletListItem(lines[idx]) {
            let line = lines[idx].trimmingCharacters(in: .whitespaces)
            // Strip leading marker (-, *, +) and space
            let content = String(line.dropFirst(2))
            items.append(content)
            idx += 1
        }

        return ParseResult(
            block: Block(type: .bulletList, content: items.joined(separator: "\n")),
            nextIndex: idx
        )
    }

    private static func parseNumberedList(lines: [String], startIndex: Int) -> ParseResult {
        var items: [String] = []
        var idx = startIndex

        while idx < lines.count && isNumberedListItem(lines[idx]) {
            let line = lines[idx].trimmingCharacters(in: .whitespaces)
            // Strip "N. " prefix
            if let dotRange = line.firstIndex(of: ".") {
                let afterDot = line.index(after: dotRange)
                let content = String(line[afterDot...]).trimmingCharacters(in: .whitespaces)
                items.append(content)
            }
            idx += 1
        }

        return ParseResult(
            block: Block(type: .numberedList, content: items.joined(separator: "\n")),
            nextIndex: idx
        )
    }

    private static func parseChecklist(lines: [String], startIndex: Int) -> ParseResult {
        var items: [String] = []
        var checkedIndices: [String] = []
        var idx = startIndex

        while idx < lines.count && isChecklistItem(lines[idx]) {
            let line = lines[idx].trimmingCharacters(in: .whitespaces)
            let isChecked = line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ")
            let content = String(line.dropFirst(6)) // Drop "- [ ] " or "- [x] "
            if isChecked {
                checkedIndices.append(String(items.count))
            }
            items.append(content)
            idx += 1
        }

        var metadata: [String: String]? = nil
        if !checkedIndices.isEmpty {
            metadata = ["checked": checkedIndices.joined(separator: ",")]
        }

        return ParseResult(
            block: Block(type: .checklist, content: items.joined(separator: "\n"), metadata: metadata),
            nextIndex: idx
        )
    }

    private static func parseParagraph(lines: [String], startIndex: Int) -> ParseResult {
        var paragraphLines: [String] = []
        var idx = startIndex

        while idx < lines.count {
            let line = lines[idx]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Stop at blank lines or special block starters
            if trimmed.isEmpty { break }
            if trimmed.hasPrefix("#") && parseHeading(line) != nil { break }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { break }
            if isDivider(trimmed) { break }
            if trimmed.hasPrefix(">") { break }
            if isBulletListItem(line) { break }
            if isNumberedListItem(line) { break }
            if isChecklistItem(line) { break }
            if parseImage(line) != nil { break }
            if parseAudio(line) != nil { break }

            paragraphLines.append(line)
            idx += 1
        }

        return ParseResult(
            block: Block(type: .paragraph, content: paragraphLines.joined(separator: "\n")),
            nextIndex: idx
        )
    }
}

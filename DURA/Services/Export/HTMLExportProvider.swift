import Foundation

struct HTMLExportProvider: ExportProvider {
    static let format = ExportFormat.html

    func export(title: String, markdown: String, progress: @Sendable (Double) -> Void) async throws -> ExportResult {
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExportError.emptyContent
        }

        progress(0.2)

        let bodyHTML = Self.renderHTML(from: markdown)

        progress(0.7)

        let fullHTML = Self.wrapInDocument(title: title, body: bodyHTML)

        guard let data = fullHTML.data(using: .utf8) else {
            throw ExportError.renderFailed("UTF-8 encoding failed")
        }

        let filename = sanitizeFilename(title) + ".html"

        progress(1.0)

        return ExportResult(
            data: data,
            filename: filename,
            utType: ExportFormat.html.utType,
            mimeType: ExportFormat.html.mimeType
        )
    }

    // MARK: - Public HTML Rendering (reused by WordPress)

    /// Renders markdown to body-only HTML (no `<html>` wrapper).
    static func renderHTML(from markdown: String) -> String {
        let blocks = BlockParser.parse(markdown)
        return blocks.map { renderBlock($0) }.joined(separator: "\n")
    }

    // MARK: - Block Rendering

    private static func renderBlock(_ block: Block) -> String {
        switch block.type {
        case .paragraph:
            let html = convertInlineMarkdown(escapeHTML(block.content))
            return "<p>\(html)</p>"

        case .heading(let level):
            let tag = "h\(min(max(level, 1), 6))"
            let html = convertInlineMarkdown(escapeHTML(block.content))
            return "<\(tag)>\(html)</\(tag)>"

        case .image:
            let alt = escapeHTML(block.content)
            let url = escapeHTML(block.metadata?["url"] ?? "")
            return "<figure><img src=\"\(url)\" alt=\"\(alt)\"><figcaption>\(alt)</figcaption></figure>"

        case .codeBlock:
            let language = block.metadata?["language"] ?? ""
            let code = escapeHTML(block.content)
            let langClass = language.isEmpty ? "" : " class=\"language-\(escapeHTML(language))\""
            return "<pre><code\(langClass)>\(code)</code></pre>"

        case .quote:
            let lines = block.content.components(separatedBy: "\n")
            let html = lines.map { "<p>\(convertInlineMarkdown(escapeHTML($0)))</p>" }.joined(separator: "\n")
            return "<blockquote>\(html)</blockquote>"

        case .bulletList:
            let items = block.content.components(separatedBy: "\n")
            let lis = items.map { "<li>\(convertInlineMarkdown(escapeHTML($0)))</li>" }.joined(separator: "\n")
            return "<ul>\n\(lis)\n</ul>"

        case .numberedList:
            let items = block.content.components(separatedBy: "\n")
            let lis = items.map { "<li>\(convertInlineMarkdown(escapeHTML($0)))</li>" }.joined(separator: "\n")
            return "<ol>\n\(lis)\n</ol>"

        case .checklist:
            let items = block.content.components(separatedBy: "\n")
            let checks = Set(block.metadata?["checked"]?.components(separatedBy: ",") ?? [])
            let lis = items.enumerated().map { idx, item in
                let checked = checks.contains(String(idx)) ? " checked disabled" : " disabled"
                return "<li><input type=\"checkbox\"\(checked)> \(convertInlineMarkdown(escapeHTML(item)))</li>"
            }.joined(separator: "\n")
            return "<ul style=\"list-style: none; padding-left: 0;\">\n\(lis)\n</ul>"

        case .toggle:
            let summary = escapeHTML(block.metadata?["summary"] ?? "Details")
            let content = convertInlineMarkdown(escapeHTML(block.content))
            return "<details>\n<summary>\(summary)</summary>\n<p>\(content)</p>\n</details>"

        case .divider:
            return "<hr>"

        case .embed:
            let url = escapeHTML(block.metadata?["url"] ?? block.content)
            return "<iframe src=\"\(url)\" frameborder=\"0\" allowfullscreen style=\"width: 100%; height: 400px;\"></iframe>"

        case .audio:
            let filename = escapeHTML(block.metadata?["filename"] ?? "audio")
            let src = escapeHTML(block.content)
            return "<audio controls><source src=\"\(src)\"></audio>\n<p>\(filename)</p>"
        }
    }

    // MARK: - Inline Markdown

    static func convertInlineMarkdown(_ text: String) -> String {
        var result = text

        // Bold: **text** or __text__
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"__(.+?)__"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )

        // Italic: *text* or _text_
        result = result.replacingOccurrences(
            of: #"\*(.+?)\*"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?<!\w)_(.+?)_(?!\w)"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )

        // Inline code: `code`
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "<code>$1</code>",
            options: .regularExpression
        )

        // Links: [text](url)
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#,
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )

        return result
    }

    // MARK: - HTML Escaping

    static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Document Wrapper

    static func wrapInDocument(title: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(escapeHTML(title))</title>
        <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 2rem;
            color: #333;
        }
        h1, h2, h3, h4, h5, h6 { margin-top: 1.5em; margin-bottom: 0.5em; }
        h1 { font-size: 2em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; }
        pre {
            background: #f6f8fa;
            border-radius: 6px;
            padding: 1em;
            overflow-x: auto;
        }
        code { font-family: 'SF Mono', Menlo, monospace; font-size: 0.9em; }
        :not(pre) > code { background: #f0f0f0; padding: 0.2em 0.4em; border-radius: 3px; }
        blockquote {
            border-left: 4px solid #ddd;
            margin: 1em 0;
            padding: 0.5em 1em;
            color: #666;
        }
        img { max-width: 100%; height: auto; border-radius: 4px; }
        figure { margin: 1em 0; }
        figcaption { font-size: 0.9em; color: #666; margin-top: 0.5em; }
        hr { border: none; border-top: 1px solid #eee; margin: 2em 0; }
        details { margin: 1em 0; }
        summary { cursor: pointer; font-weight: 600; }
        a { color: #0366d6; text-decoration: none; }
        a:hover { text-decoration: underline; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}

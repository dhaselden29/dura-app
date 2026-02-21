import Foundation
import UniformTypeIdentifiers

struct HTMLImportProvider: ImportProvider {
    static let supportedTypes: [UTType] = [
        UTType("public.html")!,
        UTType(filenameExtension: "htm")!,
    ]

    func process(data: Data, filename: String, progress: @Sendable (Double) -> Void) async throws -> ImportResult {
        guard !data.isEmpty else { throw ImportError.emptyFile }

        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.encodingFailed
        }

        progress(0.3)

        let cleaned = stripNonContentTags(html)
        let markdown = HTMLMarkdownConverter.convert(cleaned)

        progress(0.8)

        let title = extractTitle(from: html) ?? filenameStem(filename)

        progress(1.0)

        return ImportResult(
            title: title,
            body: markdown,
            source: .web,
            originalFilename: filename,
            originalData: data,
            mimeType: "text/html"
        )
    }

    private func stripNonContentTags(_ html: String) -> String {
        var result = html
        let tagsToStrip = ["script", "style", "nav", "footer", "header", "aside"]
        for tag in tagsToStrip {
            let pattern = "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
            }
        }
        return result
    }

    private func extractTitle(from html: String) -> String? {
        // Try <title> tag first
        if let titleMatch = html.range(of: "<title[^>]*>(.*?)</title>", options: [.regularExpression, .caseInsensitive]) {
            let content = String(html[titleMatch])
            if let openEnd = content.firstIndex(of: ">"),
               let closeStart = content.range(of: "</")?.lowerBound {
                let title = String(content[content.index(after: openEnd)..<closeStart])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { return title }
            }
        }
        // Fallback to first <h1>
        if let h1Match = html.range(of: "<h1[^>]*>(.*?)</h1>", options: [.regularExpression, .caseInsensitive]) {
            let content = String(html[h1Match])
            if let openEnd = content.firstIndex(of: ">"),
               let closeStart = content.range(of: "</")?.lowerBound {
                let title = String(content[content.index(after: openEnd)..<closeStart])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                if !title.isEmpty { return title }
            }
        }
        return nil
    }
}

// MARK: - HTML to Markdown Converter

/// SAX-style HTML → Markdown converter using XMLParser.
/// Internal visibility so EPUBImportProvider can reuse it.
final class HTMLMarkdownConverter: NSObject, XMLParserDelegate {

    static func convert(_ html: String) -> String {
        let converter = HTMLMarkdownConverter()
        // Wrap in root element for valid XML parsing
        let wrapped = "<root>\(html)</root>"
        // Clean up common HTML entities and issues for XML parsing
        let cleaned = prepareForXML(wrapped)
        guard let data = cleaned.data(using: .utf8) else { return html }

        let parser = XMLParser(data: data)
        parser.delegate = converter
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        parser.parse()

        return converter.result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func prepareForXML(_ html: String) -> String {
        var s = html
        // Replace common HTML entities not valid in XML
        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&ldquo;", "\u{201C}"),
            ("&rdquo;", "\u{201D}"),
            ("&lsquo;", "\u{2018}"),
            ("&rsquo;", "\u{2019}"),
            ("&mdash;", "\u{2014}"),
            ("&ndash;", "\u{2013}"),
            ("&hellip;", "\u{2026}"),
            ("&trade;", "\u{2122}"),
            ("&copy;", "\u{00A9}"),
            ("&reg;", "\u{00AE}"),
            ("&amp;", "&"),
        ]
        for (entity, replacement) in entities {
            s = s.replacingOccurrences(of: entity, with: replacement)
        }
        // Remove remaining HTML entities that aren't valid XML
        if let regex = try? NSRegularExpression(pattern: "&[a-zA-Z]+;") {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        // Handle self-closing tags like <br>, <img>, <hr>
        let selfClosing = ["br", "hr", "img", "input", "meta", "link", "source", "wbr"]
        for tag in selfClosing {
            // Replace <br> with <br/>
            if let regex = try? NSRegularExpression(pattern: "<\(tag)(\\s[^>]*)?>(?!</\(tag)>)", options: .caseInsensitive) {
                s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "<\(tag)$1/>")
            }
        }
        return s
    }

    // MARK: - State

    private var result = ""
    private var elementStack: [String] = []
    private var currentText = ""
    private var listStack: [ListType] = []  // nested list tracking
    private var linkURL: String?
    private var imageAlt: String?
    private var imageSrc: String?

    private enum ListType {
        case ordered(counter: Int)
        case unordered
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let tag = elementName.lowercased()
        flushText()
        elementStack.append(tag)

        switch tag {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            ensureNewlines(2)
        case "p", "div":
            ensureNewlines(2)
        case "br":
            result += "\n"
        case "ul":
            ensureNewlines(1)
            listStack.append(.unordered)
        case "ol":
            ensureNewlines(1)
            listStack.append(.ordered(counter: 0))
        case "li":
            ensureNewlines(1)
            let indent = String(repeating: "  ", count: max(0, listStack.count - 1))
            if var last = listStack.last {
                switch last {
                case .unordered:
                    result += "\(indent)- "
                case .ordered(var counter):
                    counter += 1
                    result += "\(indent)\(counter). "
                    last = .ordered(counter: counter)
                    listStack[listStack.count - 1] = last
                }
            }
        case "blockquote":
            ensureNewlines(2)
        case "pre":
            ensureNewlines(2)
            result += "```\n"
        case "code":
            if !elementStack.contains("pre") {
                result += "`"
            }
        case "strong", "b":
            result += "**"
        case "em", "i":
            result += "*"
        case "del", "s":
            result += "~~"
        case "a":
            linkURL = attributes["href"]
            result += "["
        case "img":
            let alt = attributes["alt"] ?? ""
            let src = attributes["src"] ?? ""
            result += "![\(alt)](\(src))"
        case "hr":
            ensureNewlines(2)
            result += "---"
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let tag = elementName.lowercased()
        flushText()

        switch tag {
        case "h1":
            let text = popInlineText()
            result += "# \(text)"
            ensureNewlines(2)
        case "h2":
            let text = popInlineText()
            result += "## \(text)"
            ensureNewlines(2)
        case "h3":
            let text = popInlineText()
            result += "### \(text)"
            ensureNewlines(2)
        case "h4":
            let text = popInlineText()
            result += "#### \(text)"
            ensureNewlines(2)
        case "h5":
            let text = popInlineText()
            result += "##### \(text)"
            ensureNewlines(2)
        case "h6":
            let text = popInlineText()
            result += "###### \(text)"
            ensureNewlines(2)
        case "p", "div":
            ensureNewlines(2)
        case "ul", "ol":
            listStack.removeLast()
            ensureNewlines(2)
        case "li":
            break
        case "blockquote":
            // Prefix lines with >
            ensureNewlines(2)
        case "pre":
            result += "\n```"
            ensureNewlines(2)
        case "code":
            if !elementStack.dropLast().contains("pre") {
                result += "`"
            }
        case "strong", "b":
            result += "**"
        case "em", "i":
            result += "*"
        case "del", "s":
            result += "~~"
        case "a":
            if let url = linkURL {
                result += "](\(url))"
            } else {
                result += "]"
            }
            linkURL = nil
        default:
            break
        }

        if elementStack.last == tag {
            elementStack.removeLast()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // Continue with what we have
    }

    // MARK: - Helpers

    private func flushText() {
        guard !currentText.isEmpty else { return }
        let inPre = elementStack.contains("pre")
        if inPre {
            result += currentText
        } else {
            // Collapse whitespace
            let collapsed = currentText
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            result += collapsed
        }
        currentText = ""
    }

    private func ensureNewlines(_ count: Int) {
        let trimmed = result.reversed()
        var existing = 0
        for ch in trimmed {
            if ch == "\n" { existing += 1 }
            else { break }
        }
        let needed = max(0, count - existing)
        result += String(repeating: "\n", count: needed)
    }

    private func popInlineText() -> String {
        // The heading text was already appended to result via foundCharacters;
        // this is a no-op placeholder since text is inline
        return ""
    }
}

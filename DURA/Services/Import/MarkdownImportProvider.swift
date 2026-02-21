import Foundation
import UniformTypeIdentifiers

struct MarkdownImportProvider: ImportProvider {
    static let supportedTypes: [UTType] = [.markdown]

    func process(data: Data, filename: String, progress: @Sendable (Double) -> Void) async throws -> ImportResult {
        guard !data.isEmpty else { throw ImportError.emptyFile }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ImportError.encodingFailed
        }

        progress(0.3)

        let (frontMatter, body) = parseFrontMatter(from: text)

        progress(0.6)

        let title: String
        if let fmTitle = frontMatter?["title"], !fmTitle.isEmpty {
            title = fmTitle
        } else {
            title = extractTitle(from: body) ?? filenameStem(filename)
        }

        let source: ImportSource
        if frontMatter?["source"] == "web" {
            source = .web
        } else {
            source = .markdown
        }

        progress(1.0)

        var result = ImportResult(
            title: title,
            body: body,
            source: source,
            originalFilename: filename,
            originalData: data,
            mimeType: "text/markdown"
        )

        // Populate metadata from front matter
        if let fm = frontMatter {
            result.sourceURL = fm["url"]
            result.excerpt = fm["excerpt"]
            result.notebookName = fm["notebook"]
            result.featuredImageURL = fm["featured_image"]

            if let tagsString = fm["tags"] {
                result.tagNames = parseTagsArray(tagsString)
            }
        }

        return result
    }

    // MARK: - Front Matter Parsing

    /// Parses YAML front matter delimited by `---` at the start of the file.
    /// Returns the parsed key-value pairs and the body text with front matter stripped.
    private func parseFrontMatter(from text: String) -> ([String: String]?, String) {
        let trimmed = text.trimmingCharacters(in: .init(charactersIn: "\u{FEFF}")) // strip BOM
        guard trimmed.hasPrefix("---") else {
            return (nil, text)
        }

        // Find the closing ---
        let afterOpener = trimmed.index(trimmed.startIndex, offsetBy: 3)
        guard let closingRange = trimmed.range(
            of: "\n---",
            range: afterOpener..<trimmed.endIndex
        ) else {
            return (nil, text)
        }

        let frontMatterBlock = String(trimmed[afterOpener..<closingRange.lowerBound])
        let bodyStart = closingRange.upperBound
        let body = String(trimmed[bodyStart...]).trimmingCharacters(in: .newlines)

        // Parse key-value pairs line by line
        var dict: [String: String] = [:]
        let lines = frontMatterBlock.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }
            guard let colonIndex = trimmedLine.firstIndex(of: ":") else { continue }

            let key = String(trimmedLine[trimmedLine.startIndex..<colonIndex])
                .trimmingCharacters(in: .whitespaces)
            let rawValue = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                .trimmingCharacters(in: .whitespaces)

            // Strip surrounding quotes
            let value = stripQuotes(rawValue)
            dict[key] = value
        }

        return (dict.isEmpty ? nil : dict, body)
    }

    /// Strips surrounding double quotes and unescapes basic YAML escapes.
    private func stripQuotes(_ value: String) -> String {
        var s = value
        if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 {
            s = String(s.dropFirst().dropLast())
            s = s.replacingOccurrences(of: "\\\"", with: "\"")
            s = s.replacingOccurrences(of: "\\\\", with: "\\")
        }
        return s
    }

    /// Parses a YAML inline array like `["tag1", "tag2"]` or `[tag1, tag2]`.
    private func parseTagsArray(_ value: String) -> [String] {
        var s = value.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("[") && s.hasSuffix("]") {
            s = String(s.dropFirst().dropLast())
        }
        guard !s.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return s.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { stripQuotes($0) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Title Extraction (fallback)

    private func extractTitle(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                let title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    return title
                }
            }
        }
        return nil
    }
}

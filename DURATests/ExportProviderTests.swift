import Testing
import Foundation
import UniformTypeIdentifiers
@testable import DURA

// MARK: - Markdown Export Provider Tests

@Suite("MarkdownExportProvider")
struct MarkdownExportProviderTests {

    @Test("Prepends title as H1 when body has no heading")
    func prependsTitle() async throws {
        let provider = MarkdownExportProvider()
        let result = try await provider.export(title: "My Title", markdown: "Some body text.") { _ in }

        let content = String(data: result.data, encoding: .utf8)!
        #expect(content.hasPrefix("# My Title\n\n"))
        #expect(content.contains("Some body text."))
    }

    @Test("Does not duplicate H1 when body already starts with one")
    func noDuplicateH1() async throws {
        let provider = MarkdownExportProvider()
        let result = try await provider.export(title: "My Title", markdown: "# My Title\n\nBody text.") { _ in }

        let content = String(data: result.data, encoding: .utf8)!
        // Should not have double "# My Title"
        let headingCount = content.components(separatedBy: "# My Title").count - 1
        #expect(headingCount == 1)
    }

    @Test("Throws on empty content")
    func emptyContentThrows() async {
        let provider = MarkdownExportProvider()
        do {
            _ = try await provider.export(title: "Test", markdown: "   ") { _ in }
            Issue.record("Expected ExportError.emptyContent")
        } catch {
            #expect(error is ExportError)
        }
    }

    @Test("Returns correct filename and MIME type")
    func filenameAndMime() async throws {
        let provider = MarkdownExportProvider()
        let result = try await provider.export(title: "My Document", markdown: "Content") { _ in }

        #expect(result.filename == "My Document.md")
        #expect(result.mimeType == "text/markdown")
    }
}

// MARK: - HTML Export Provider Tests

@Suite("HTMLExportProvider")
struct HTMLExportProviderTests {

    @Test("Renders heading tags correctly")
    func headingTags() {
        let html = HTMLExportProvider.renderHTML(from: "# Title\n\n## Subtitle\n\n### Section")
        #expect(html.contains("<h1>Title</h1>"))
        #expect(html.contains("<h2>Subtitle</h2>"))
        #expect(html.contains("<h3>Section</h3>"))
    }

    @Test("Renders bullet lists")
    func bulletLists() {
        let html = HTMLExportProvider.renderHTML(from: "- Item one\n- Item two\n- Item three")
        #expect(html.contains("<ul>"))
        #expect(html.contains("<li>Item one</li>"))
        #expect(html.contains("<li>Item two</li>"))
        #expect(html.contains("</ul>"))
    }

    @Test("Renders code blocks with language class")
    func codeBlocks() {
        let html = HTMLExportProvider.renderHTML(from: "```swift\nlet x = 42\n```")
        #expect(html.contains("<pre><code class=\"language-swift\">"))
        #expect(html.contains("let x = 42"))
        #expect(html.contains("</code></pre>"))
    }

    @Test("Escapes HTML entities in content")
    func htmlEscaping() {
        let escaped = HTMLExportProvider.escapeHTML("<script>alert('xss')</script>")
        #expect(escaped.contains("&lt;script&gt;"))
        #expect(!escaped.contains("<script>"))
    }

    @Test("renderHTML returns body-only HTML without document wrapper")
    func bodyOnlyHTML() {
        let html = HTMLExportProvider.renderHTML(from: "Hello world")
        #expect(!html.contains("<!DOCTYPE"))
        #expect(!html.contains("<html"))
        #expect(html.contains("<p>Hello world</p>"))
    }

    @Test("Full export wraps in document with CSS")
    func fullDocumentExport() async throws {
        let provider = HTMLExportProvider()
        let result = try await provider.export(title: "Test", markdown: "Hello") { _ in }

        let content = String(data: result.data, encoding: .utf8)!
        #expect(content.contains("<!DOCTYPE html>"))
        #expect(content.contains("<title>Test</title>"))
        #expect(content.contains("<style>"))
        #expect(result.filename == "Test.html")
        #expect(result.mimeType == "text/html")
    }

    @Test("Converts inline markdown to HTML")
    func inlineMarkdown() {
        let result = HTMLExportProvider.convertInlineMarkdown("**bold** and *italic* and `code`")
        #expect(result.contains("<strong>bold</strong>"))
        #expect(result.contains("<em>italic</em>"))
        #expect(result.contains("<code>code</code>"))
    }

    @Test("Converts links to anchor tags")
    func inlineLinks() {
        let result = HTMLExportProvider.convertInlineMarkdown("[Google](https://google.com)")
        #expect(result.contains("<a href=\"https://google.com\">Google</a>"))
    }

    @Test("Renders numbered lists")
    func numberedLists() {
        let html = HTMLExportProvider.renderHTML(from: "1. First\n2. Second\n3. Third")
        #expect(html.contains("<ol>"))
        #expect(html.contains("<li>First</li>"))
        #expect(html.contains("</ol>"))
    }

    @Test("Renders blockquotes")
    func blockquotes() {
        let html = HTMLExportProvider.renderHTML(from: "> A wise quote")
        #expect(html.contains("<blockquote>"))
        #expect(html.contains("A wise quote"))
        #expect(html.contains("</blockquote>"))
    }

    @Test("Renders dividers")
    func dividers() {
        let html = HTMLExportProvider.renderHTML(from: "Before\n\n---\n\nAfter")
        #expect(html.contains("<hr>"))
    }
}

// MARK: - Sanitize Filename Tests

@Suite("sanitizeFilename")
struct SanitizeFilenameTests {

    @Test("Removes invalid characters")
    func removesInvalidChars() {
        #expect(sanitizeFilename("my/file:name") == "myfilename")
        #expect(sanitizeFilename("test<>file") == "testfile")
    }

    @Test("Returns Untitled for empty string")
    func emptyString() {
        #expect(sanitizeFilename("") == "Untitled")
        #expect(sanitizeFilename("   ") == "Untitled")
    }

    @Test("Preserves valid characters")
    func preservesValid() {
        #expect(sanitizeFilename("My Document 2024") == "My Document 2024")
    }
}

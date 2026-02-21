import Testing
import Foundation
@testable import DURA

@Suite("Front Matter Import")
struct FrontMatterImportTests {

    private let provider = MarkdownImportProvider()

    // MARK: - Full Front Matter

    @Test("Parses front matter with all fields populated")
    func allFields() async throws {
        let markdown = """
        ---
        title: "Test Article"
        url: "https://example.com/article"
        author: "Jane Doe"
        clipped_at: "2026-02-21T14:30:00Z"
        source: "web"
        type: "article"
        tags: ["swift", "ios", "testing"]
        notebook: "Research"
        excerpt: "A short excerpt about the article."
        featured_image: "https://example.com/image.jpg"
        ---

        # Test Article

        > Clipped from example.com on February 21, 2026

        This is the body of the article.
        """

        let data = markdown.data(using: .utf8)!
        let result = try await provider.process(data: data, filename: "test.md") { _ in }

        #expect(result.title == "Test Article")
        #expect(result.source == .web)
        #expect(result.sourceURL == "https://example.com/article")
        #expect(result.excerpt == "A short excerpt about the article.")
        #expect(result.notebookName == "Research")
        #expect(result.featuredImageURL == "https://example.com/image.jpg")
        #expect(result.tagNames == ["swift", "ios", "testing"])

        // Body should NOT contain front matter
        #expect(!result.body.contains("---"))
        #expect(result.body.contains("This is the body of the article."))
    }

    // MARK: - Minimal Front Matter

    @Test("Parses front matter with minimal fields")
    func minimalFields() async throws {
        let markdown = """
        ---
        title: "Quick Bookmark"
        url: "https://example.com"
        ---

        Some content here.
        """

        let data = markdown.data(using: .utf8)!
        let result = try await provider.process(data: data, filename: "bookmark.md") { _ in }

        #expect(result.title == "Quick Bookmark")
        #expect(result.sourceURL == "https://example.com")
        #expect(result.source == .markdown) // no source: "web" field
        #expect(result.tagNames == nil)
        #expect(result.notebookName == nil)
    }

    // MARK: - No Front Matter

    @Test("No front matter preserves existing behavior")
    func noFrontMatter() async throws {
        let markdown = "# Regular Document\n\nJust a normal markdown file."
        let data = markdown.data(using: .utf8)!

        let result = try await provider.process(data: data, filename: "normal.md") { _ in }

        #expect(result.title == "Regular Document")
        #expect(result.source == .markdown)
        #expect(result.sourceURL == nil)
        #expect(result.tagNames == nil)
        #expect(result.notebookName == nil)
        #expect(result.body == markdown)
    }

    // MARK: - Tags Array Parsing

    @Test("Parses tags from YAML array")
    func tagsArray() async throws {
        let markdown = """
        ---
        title: "Tagged"
        tags: ["alpha", "beta", "gamma"]
        ---

        Body text.
        """

        let data = markdown.data(using: .utf8)!
        let result = try await provider.process(data: data, filename: "tagged.md") { _ in }

        #expect(result.tagNames == ["alpha", "beta", "gamma"])
    }

    @Test("Parses empty tags array")
    func emptyTagsArray() async throws {
        let markdown = """
        ---
        title: "No Tags"
        tags: []
        ---

        Body text.
        """

        let data = markdown.data(using: .utf8)!
        let result = try await provider.process(data: data, filename: "notags.md") { _ in }

        #expect(result.tagNames == [])
    }

    // MARK: - Source Detection

    @Test("source: web sets ImportSource.web")
    func webSource() async throws {
        let markdown = """
        ---
        title: "Web Clip"
        source: "web"
        ---

        Clipped content.
        """

        let data = markdown.data(using: .utf8)!
        let result = try await provider.process(data: data, filename: "clip.md") { _ in }

        #expect(result.source == .web)
    }

    @Test("source: other value keeps markdown source")
    func nonWebSource() async throws {
        let markdown = """
        ---
        title: "Other Source"
        source: "email"
        ---

        Content.
        """

        let data = markdown.data(using: .utf8)!
        let result = try await provider.process(data: data, filename: "other.md") { _ in }

        #expect(result.source == .markdown)
    }

    // MARK: - Body Stripping

    @Test("Body is correctly stripped of front matter")
    func bodyStripped() async throws {
        let markdown = """
        ---
        title: "Stripped"
        url: "https://example.com"
        ---

        # Stripped

        The actual body content starts here.

        Second paragraph.
        """

        let data = markdown.data(using: .utf8)!
        let result = try await provider.process(data: data, filename: "strip.md") { _ in }

        #expect(!result.body.hasPrefix("---"))
        #expect(result.body.contains("The actual body content starts here."))
        #expect(result.body.contains("Second paragraph."))
    }

    // MARK: - Title Precedence

    @Test("Title from front matter takes precedence over heading in body")
    func titlePrecedence() async throws {
        let markdown = """
        ---
        title: "Front Matter Title"
        ---

        # Body Heading Title

        Some content.
        """

        let data = markdown.data(using: .utf8)!
        let result = try await provider.process(data: data, filename: "precedence.md") { _ in }

        #expect(result.title == "Front Matter Title")
    }

    @Test("Falls back to body heading when front matter title is empty")
    func emptyFrontMatterTitle() async throws {
        let markdown = """
        ---
        title: ""
        url: "https://example.com"
        ---

        # Body Title

        Content.
        """

        let data = markdown.data(using: .utf8)!
        let result = try await provider.process(data: data, filename: "fallback.md") { _ in }

        #expect(result.title == "Body Title")
    }

    // MARK: - Invalid Front Matter

    @Test("Malformed front matter treated as regular markdown")
    func malformedFrontMatter() async throws {
        let markdown = """
        ---
        this is not valid yaml
        just random text
        """

        let data = markdown.data(using: .utf8)!
        let result = try await provider.process(data: data, filename: "malformed.md") { _ in }

        // No closing --- so it's treated as regular markdown
        #expect(result.source == .markdown)
        #expect(result.sourceURL == nil)
        #expect(result.title == "malformed") // falls back to filename
    }

    @Test("Front matter with escaped quotes in title")
    func escapedQuotes() async throws {
        let markdown = """
        ---
        title: "He said \\"hello\\""
        url: "https://example.com"
        ---

        Body.
        """

        let data = markdown.data(using: .utf8)!
        let result = try await provider.process(data: data, filename: "escaped.md") { _ in }

        #expect(result.title == "He said \"hello\"")
    }
}

import Testing
import Foundation
@testable import DURA

@Suite("ArticleHTMLRenderer")
struct ArticleHTMLRendererTests {

    @Test("Rendered HTML contains img tags for markdown images")
    func containsImageTags() {
        let markdown = "# Title\n\n![Photo](https://example.com/photo.jpg)\n\nSome text."
        let html = ArticleHTMLRenderer.render(markdown: markdown)

        #expect(html.contains("<img"))
        #expect(html.contains("src=\"https://example.com/photo.jpg\""))
        #expect(html.contains("alt=\"Photo\""))
    }

    @Test("Highlight JavaScript includes anchor text data")
    func highlightJSIncludesAnchorText() {
        let highlight = Highlight(
            anchorText: "important phrase",
            rangeStart: 10,
            rangeLength: 16,
            color: .yellow
        )
        let html = ArticleHTMLRenderer.render(
            markdown: "This is an important phrase in the text.",
            highlights: [highlight]
        )

        #expect(html.contains("important phrase"))
        #expect(html.contains("yellow"))
        #expect(html.contains(highlight.id.uuidString))
    }

    @Test("CSS custom properties match theme values")
    func cssPropertiesMatchTheme() {
        for theme in ReaderTheme.allCases {
            let html = ArticleHTMLRenderer.render(markdown: "Hello", theme: theme)
            #expect(html.contains(theme.cssBackground))
            #expect(html.contains(theme.cssTextColor))
        }
    }

    @Test("Font family CSS values are correct")
    func fontFamilyCSSValues() {
        #expect(ReaderFont.system.cssValue.contains("apple-system"))
        #expect(ReaderFont.serif.cssValue.contains("Georgia"))
        #expect(ReaderFont.mono.cssValue.contains("Menlo"))
        #expect(ReaderFont.openDyslexic.cssValue.contains("OpenDyslexic"))

        let html = ArticleHTMLRenderer.render(markdown: "Test", fontFamily: .serif)
        #expect(html.contains(ReaderFont.serif.cssValue))
    }

    @Test("Empty markdown produces valid HTML document")
    func emptyMarkdownProducesValidDocument() {
        let html = ArticleHTMLRenderer.render(markdown: "")

        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("<html"))
        #expect(html.contains("</html>"))
        #expect(html.contains("<body>"))
        #expect(html.contains("</body>"))
    }

    @Test("Multiple highlights produce valid JSON array")
    func multipleHighlights() {
        let highlights = [
            Highlight(anchorText: "first", rangeStart: 0, rangeLength: 5, color: .yellow),
            Highlight(anchorText: "second", rangeStart: 10, rangeLength: 6, color: .blue),
        ]
        let html = ArticleHTMLRenderer.render(
            markdown: "first and second text",
            highlights: highlights
        )

        #expect(html.contains("\"first\""))
        #expect(html.contains("\"second\""))
        #expect(html.contains("yellow"))
        #expect(html.contains("blue"))
    }

    @Test("Highlight anchor text with special characters is escaped")
    func highlightSpecialCharacterEscaping() {
        let highlight = Highlight(
            anchorText: "text with \"quotes\" and \\backslash",
            rangeStart: 0,
            rangeLength: 33,
            color: .green
        )
        let html = ArticleHTMLRenderer.render(
            markdown: "text with \"quotes\" and \\backslash",
            highlights: [highlight]
        )

        // Should not contain unescaped quotes that would break JSON
        #expect(html.contains("\\\"quotes\\\""))
        #expect(html.contains("\\\\backslash"))
    }

    @Test("HighlightColor CSS values use rgba format")
    func highlightColorCSSValues() {
        for color in HighlightColor.allCases {
            #expect(color.cssColor.hasPrefix("rgba("))
            #expect(color.cssColor.hasSuffix(")"))
            #expect(color.cssColor.contains("0.35"))
        }
    }

    @Test("Scroll progress JavaScript is present")
    func scrollProgressJSPresent() {
        let html = ArticleHTMLRenderer.render(markdown: "Test content")
        #expect(html.contains("scrollProgress"))
        #expect(html.contains("messageHandlers"))
    }

    @Test("Selection change JavaScript is present")
    func selectionChangeJSPresent() {
        let html = ArticleHTMLRenderer.render(markdown: "Test content")
        #expect(html.contains("selectionchange"))
        #expect(html.contains("selectionChanged"))
    }

    @Test("Dynamic update functions are present")
    func dynamicUpdateFunctionsPresent() {
        let html = ArticleHTMLRenderer.render(markdown: "Test")
        #expect(html.contains("function updateTheme("))
        #expect(html.contains("function updateFont("))
        #expect(html.contains("function updateFontSize("))
        #expect(html.contains("function updateLineSpacing("))
        #expect(html.contains("function updateMaxWidth("))
        #expect(html.contains("function scrollToHighlight("))
    }

    @Test("Font size and line spacing are reflected in CSS")
    func fontSizeAndLineSpacing() {
        let html = ArticleHTMLRenderer.render(markdown: "Test", fontSize: 22, lineSpacing: 8)
        #expect(html.contains("22px"))
    }

    @Test("Max width is reflected in CSS")
    func maxWidthCSS() {
        let constrained = ArticleHTMLRenderer.render(markdown: "Test", maxWidth: 700)
        #expect(constrained.contains("700px"))

        let fullWidth = ArticleHTMLRenderer.render(markdown: "Test", maxWidth: 100000)
        #expect(fullWidth.contains("100%"))
    }
}

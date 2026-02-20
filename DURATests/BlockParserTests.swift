import Testing
@testable import DURA

@Suite("BlockParser")
struct BlockParserTests {

    // MARK: - Empty / Minimal Input

    @Test("Empty string returns single empty paragraph")
    func emptyInput() {
        let blocks = BlockParser.parse("")
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .paragraph)
        #expect(blocks[0].content == "")
    }

    @Test("Whitespace-only string returns single empty paragraph")
    func whitespaceOnly() {
        let blocks = BlockParser.parse("   \n   \n  ")
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .paragraph)
    }

    // MARK: - Paragraphs

    @Test("Single line paragraph")
    func singleParagraph() {
        let blocks = BlockParser.parse("Hello world")
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .paragraph)
        #expect(blocks[0].content == "Hello world")
    }

    @Test("Multi-line paragraph joined")
    func multiLineParagraph() {
        let blocks = BlockParser.parse("Line one\nLine two\nLine three")
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .paragraph)
        #expect(blocks[0].content == "Line one\nLine two\nLine three")
    }

    @Test("Two paragraphs separated by blank line")
    func twoParagraphs() {
        let blocks = BlockParser.parse("First paragraph\n\nSecond paragraph")
        #expect(blocks.count == 2)
        #expect(blocks[0].content == "First paragraph")
        #expect(blocks[1].content == "Second paragraph")
    }

    // MARK: - Headings

    @Test("Heading levels 1 through 6")
    func headingLevels() {
        for level in 1...6 {
            let prefix = String(repeating: "#", count: level)
            let blocks = BlockParser.parse("\(prefix) Heading \(level)")
            #expect(blocks.count == 1)
            #expect(blocks[0].type == .heading(level: level))
            #expect(blocks[0].content == "Heading \(level)")
        }
    }

    @Test("Heading requires space after hashes")
    func headingRequiresSpace() {
        let blocks = BlockParser.parse("#NoSpace")
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .paragraph)
    }

    @Test("Seven hashes is not a heading")
    func sevenHashes() {
        let blocks = BlockParser.parse("####### Not a heading")
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .paragraph)
    }

    // MARK: - Dividers

    @Test("Dash divider")
    func dashDivider() {
        let blocks = BlockParser.parse("---")
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .divider)
    }

    @Test("Asterisk divider")
    func asteriskDivider() {
        let blocks = BlockParser.parse("***")
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .divider)
    }

    @Test("Underscore divider")
    func underscoreDivider() {
        let blocks = BlockParser.parse("___")
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .divider)
    }

    @Test("Two dashes is not a divider")
    func twoDashesNotDivider() {
        let blocks = BlockParser.parse("--")
        #expect(blocks[0].type == .paragraph)
    }

    // MARK: - Bullet Lists

    @Test("Dash bullet list")
    func dashBulletList() {
        let md = "- Apple\n- Banana\n- Cherry"
        let blocks = BlockParser.parse(md)
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .bulletList)
        #expect(blocks[0].content == "Apple\nBanana\nCherry")
    }

    @Test("Asterisk bullet list")
    func asteriskBulletList() {
        let md = "* One\n* Two"
        let blocks = BlockParser.parse(md)
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .bulletList)
        #expect(blocks[0].content == "One\nTwo")
    }

    @Test("Plus bullet list")
    func plusBulletList() {
        let md = "+ A\n+ B"
        let blocks = BlockParser.parse(md)
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .bulletList)
    }

    // MARK: - Numbered Lists

    @Test("Numbered list")
    func numberedList() {
        let md = "1. First\n2. Second\n3. Third"
        let blocks = BlockParser.parse(md)
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .numberedList)
        #expect(blocks[0].content == "First\nSecond\nThird")
    }

    // MARK: - Checklists

    @Test("Checklist with mixed states")
    func checklistMixed() {
        let md = "- [ ] Todo\n- [x] Done\n- [ ] Another"
        let blocks = BlockParser.parse(md)
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .checklist)
        #expect(blocks[0].content == "Todo\nDone\nAnother")
        #expect(blocks[0].metadata?["checked"] == "1")
    }

    @Test("Checklist all checked")
    func checklistAllChecked() {
        let md = "- [x] A\n- [X] B"
        let blocks = BlockParser.parse(md)
        #expect(blocks[0].metadata?["checked"] == "0,1")
    }

    @Test("Checklist none checked")
    func checklistNoneChecked() {
        let md = "- [ ] A\n- [ ] B"
        let blocks = BlockParser.parse(md)
        #expect(blocks[0].metadata == nil)
    }

    // MARK: - Blockquotes

    @Test("Single line blockquote")
    func singleQuote() {
        let blocks = BlockParser.parse("> Hello world")
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .quote)
        #expect(blocks[0].content == "Hello world")
    }

    @Test("Multi-line blockquote")
    func multiLineQuote() {
        let md = "> Line one\n> Line two"
        let blocks = BlockParser.parse(md)
        #expect(blocks[0].type == .quote)
        #expect(blocks[0].content == "Line one\nLine two")
    }

    // MARK: - Code Blocks

    @Test("Fenced code block with language")
    func codeBlockWithLanguage() {
        let md = "```swift\nlet x = 42\nprint(x)\n```"
        let blocks = BlockParser.parse(md)
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .codeBlock)
        #expect(blocks[0].content == "let x = 42\nprint(x)")
        #expect(blocks[0].metadata?["language"] == "swift")
    }

    @Test("Fenced code block without language")
    func codeBlockNoLanguage() {
        let md = "```\nhello\n```"
        let blocks = BlockParser.parse(md)
        #expect(blocks[0].type == .codeBlock)
        #expect(blocks[0].content == "hello")
        #expect(blocks[0].metadata == nil)
    }

    @Test("Tilde fenced code block")
    func tildeCodeBlock() {
        let md = "~~~python\nprint('hi')\n~~~"
        let blocks = BlockParser.parse(md)
        #expect(blocks[0].type == .codeBlock)
        #expect(blocks[0].metadata?["language"] == "python")
    }

    @Test("Code block preserves blank lines")
    func codeBlockPreservesBlankLines() {
        let md = "```\nline1\n\nline3\n```"
        let blocks = BlockParser.parse(md)
        #expect(blocks[0].content == "line1\n\nline3")
    }

    // MARK: - Images

    @Test("Image block")
    func imageBlock() {
        let blocks = BlockParser.parse("![Alt text](https://example.com/img.png)")
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .image)
        #expect(blocks[0].content == "Alt text")
        #expect(blocks[0].metadata?["url"] == "https://example.com/img.png")
    }

    @Test("Image with empty alt")
    func imageEmptyAlt() {
        let blocks = BlockParser.parse("![](photo.jpg)")
        #expect(blocks[0].type == .image)
        #expect(blocks[0].content == "")
        #expect(blocks[0].metadata?["url"] == "photo.jpg")
    }

    // MARK: - Mixed Content

    @Test("Heading followed by paragraph")
    func headingThenParagraph() {
        let md = "# Title\n\nSome text here."
        let blocks = BlockParser.parse(md)
        #expect(blocks.count == 2)
        #expect(blocks[0].type == .heading(level: 1))
        #expect(blocks[1].type == .paragraph)
    }

    @Test("Complex mixed document")
    func complexDocument() {
        let md = """
        # Title

        Some intro text.

        ## Section

        - Item A
        - Item B

        > A quote

        ```swift
        let code = true
        ```

        ---

        Final paragraph.
        """
        let blocks = BlockParser.parse(md)
        #expect(blocks.count == 8)
        #expect(blocks[0].type == .heading(level: 1))
        #expect(blocks[1].type == .paragraph)
        #expect(blocks[2].type == .heading(level: 2))
        #expect(blocks[3].type == .bulletList)
        #expect(blocks[4].type == .quote)
        #expect(blocks[5].type == .codeBlock)
        #expect(blocks[6].type == .divider)
        #expect(blocks[7].type == .paragraph)
    }

    // MARK: - Render (Blocks → Markdown)

    @Test("Render paragraph")
    func renderParagraph() {
        let blocks = [Block(type: .paragraph, content: "Hello")]
        #expect(BlockParser.render(blocks) == "Hello")
    }

    @Test("Render heading")
    func renderHeading() {
        let blocks = [Block(type: .heading(level: 2), content: "Title")]
        #expect(BlockParser.render(blocks) == "## Title")
    }

    @Test("Render bullet list")
    func renderBulletList() {
        let blocks = [Block(type: .bulletList, content: "A\nB\nC")]
        #expect(BlockParser.render(blocks) == "- A\n- B\n- C")
    }

    @Test("Render numbered list")
    func renderNumberedList() {
        let blocks = [Block(type: .numberedList, content: "First\nSecond")]
        #expect(BlockParser.render(blocks) == "1. First\n2. Second")
    }

    @Test("Render checklist")
    func renderChecklist() {
        let blocks = [Block(type: .checklist, content: "Todo\nDone", metadata: ["checked": "1"])]
        #expect(BlockParser.render(blocks) == "- [ ] Todo\n- [x] Done")
    }

    @Test("Render blockquote")
    func renderQuote() {
        let blocks = [Block(type: .quote, content: "Wise words")]
        #expect(BlockParser.render(blocks) == "> Wise words")
    }

    @Test("Render code block")
    func renderCodeBlock() {
        let blocks = [Block(type: .codeBlock, content: "let x = 1", metadata: ["language": "swift"])]
        #expect(BlockParser.render(blocks) == "```swift\nlet x = 1\n```")
    }

    @Test("Render image")
    func renderImage() {
        let blocks = [Block(type: .image, content: "Photo", metadata: ["url": "pic.jpg"])]
        #expect(BlockParser.render(blocks) == "![Photo](pic.jpg)")
    }

    @Test("Render divider")
    func renderDivider() {
        let blocks = [Block(type: .divider, content: "")]
        #expect(BlockParser.render(blocks) == "---")
    }

    // MARK: - Round-trip (Parse → Render → Parse)

    @Test("Round-trip: heading")
    func roundTripHeading() {
        let original = "## My Heading"
        let blocks = BlockParser.parse(original)
        let rendered = BlockParser.render(blocks)
        let reparsed = BlockParser.parse(rendered)
        #expect(blocks.count == reparsed.count)
        #expect(blocks[0].type == reparsed[0].type)
        #expect(blocks[0].content == reparsed[0].content)
    }

    @Test("Round-trip: bullet list")
    func roundTripBulletList() {
        let original = "- A\n- B\n- C"
        let blocks = BlockParser.parse(original)
        let rendered = BlockParser.render(blocks)
        let reparsed = BlockParser.parse(rendered)
        #expect(blocks[0].content == reparsed[0].content)
    }

    @Test("Round-trip: code block")
    func roundTripCodeBlock() {
        let original = "```swift\nlet x = 42\n```"
        let blocks = BlockParser.parse(original)
        let rendered = BlockParser.render(blocks)
        let reparsed = BlockParser.parse(rendered)
        #expect(reparsed[0].type == .codeBlock)
        #expect(reparsed[0].content == "let x = 42")
        #expect(reparsed[0].metadata?["language"] == "swift")
    }

    @Test("Round-trip: checklist")
    func roundTripChecklist() {
        let original = "- [ ] Todo\n- [x] Done\n- [ ] Later"
        let blocks = BlockParser.parse(original)
        let rendered = BlockParser.render(blocks)
        let reparsed = BlockParser.parse(rendered)
        #expect(reparsed[0].type == .checklist)
        #expect(reparsed[0].content == blocks[0].content)
        #expect(reparsed[0].metadata?["checked"] == blocks[0].metadata?["checked"])
    }

    @Test("Multiple blocks separated by double newline in render output")
    func renderSeparation() {
        let blocks = [
            Block(type: .heading(level: 1), content: "Title"),
            Block(type: .paragraph, content: "Body text")
        ]
        let rendered = BlockParser.render(blocks)
        #expect(rendered == "# Title\n\nBody text")
    }
}

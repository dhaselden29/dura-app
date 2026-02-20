import Testing
import Foundation
import CoreGraphics
import CoreText
@testable import DURA

// MARK: - Markdown Import Provider Tests

@Suite("MarkdownImportProvider")
struct MarkdownImportProviderTests {

    @Test("Extracts title from first heading")
    func titleFromHeading() async throws {
        let markdown = "# My Document\n\nSome body text here."
        let data = markdown.data(using: .utf8)!
        let provider = MarkdownImportProvider()

        let result = try await provider.process(data: data, filename: "test.md") { _ in }

        #expect(result.title == "My Document")
        #expect(result.body == markdown)
        #expect(result.source == .markdown)
        #expect(result.mimeType == "text/markdown")
    }

    @Test("Falls back to filename stem when no heading")
    func titleFromFilename() async throws {
        let markdown = "Just some text without a heading."
        let data = markdown.data(using: .utf8)!
        let provider = MarkdownImportProvider()

        let result = try await provider.process(data: data, filename: "my-notes.md") { _ in }

        #expect(result.title == "my-notes")
    }

    @Test("Skips empty heading lines")
    func skipsEmptyHeading() async throws {
        let markdown = "#  \n\n# Real Title\n\nBody"
        let data = markdown.data(using: .utf8)!
        let provider = MarkdownImportProvider()

        let result = try await provider.process(data: data, filename: "test.md") { _ in }

        #expect(result.title == "Real Title")
    }

    @Test("Throws on empty file")
    func emptyFile() async {
        let provider = MarkdownImportProvider()
        do {
            _ = try await provider.process(data: Data(), filename: "empty.md") { _ in }
            Issue.record("Expected ImportError.emptyFile")
        } catch {
            #expect(error is ImportError)
        }
    }
}

// MARK: - Plain Text Import Provider Tests

@Suite("PlainTextImportProvider")
struct PlainTextImportProviderTests {

    @Test("Uses first non-empty line as title")
    func firstLineTitle() async throws {
        let text = "My First Line\nSecond line\nThird line"
        let data = text.data(using: .utf8)!
        let provider = PlainTextImportProvider()

        let result = try await provider.process(data: data, filename: "notes.txt") { _ in }

        #expect(result.title == "My First Line")
        #expect(result.source == .plainText)
        #expect(result.mimeType == "text/plain")
    }

    @Test("Truncates long first line to 100 characters")
    func longFirstLine() async throws {
        let longLine = String(repeating: "x", count: 200)
        let data = longLine.data(using: .utf8)!
        let provider = PlainTextImportProvider()

        let result = try await provider.process(data: data, filename: "long.txt") { _ in }

        #expect(result.title.count == 100)
    }

    @Test("Skips empty lines to find title")
    func skipsEmptyLines() async throws {
        let text = "\n\n  \nActual Title\nBody"
        let data = text.data(using: .utf8)!
        let provider = PlainTextImportProvider()

        let result = try await provider.process(data: data, filename: "test.txt") { _ in }

        #expect(result.title == "Actual Title")
    }
}

// MARK: - RTF Import Provider Tests

@Suite("RTFImportProvider")
struct RTFImportProviderTests {

    @Test("Parses basic RTF content")
    func basicRTF() async throws {
        // Minimal RTF document
        let rtfString = #"{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}} \pard Hello RTF World\par Second line\par}"#
        let data = rtfString.data(using: .utf8)!
        let provider = RTFImportProvider()

        let result = try await provider.process(data: data, filename: "document.rtf") { _ in }

        #expect(result.source == .rtf)
        #expect(result.mimeType == "application/rtf")
        #expect(result.body.contains("Hello RTF World"))
        #expect(result.title == "Hello RTF World")
    }

    @Test("Throws on empty file")
    func emptyFile() async {
        let provider = RTFImportProvider()
        do {
            _ = try await provider.process(data: Data(), filename: "empty.rtf") { _ in }
            Issue.record("Expected ImportError.emptyFile")
        } catch {
            #expect(error is ImportError)
        }
    }
}

// MARK: - PDF Import Provider Tests

@Suite("PDFImportProvider")
struct PDFImportProviderTests {

    @Test("Extracts text from text-layer PDF")
    func textLayerPDF() async throws {
        // Create a simple PDF with text layer using PDFKit
        let provider = PDFImportProvider()

        // Create a minimal PDF with text
        guard let pdfData = createTextPDFData(text: "Hello from PDF document. This is a test with enough characters to pass the threshold.") else {
            Issue.record("Could not create test PDF")
            return
        }

        let result = try await provider.process(data: pdfData, filename: "test.pdf") { _ in }

        #expect(result.source == .pdf)
        #expect(result.mimeType == "application/pdf")
        #expect(result.body.contains("Hello from PDF"))
        // Should not trigger OCR for text-layer PDF
        #expect(result.ocrText == nil)
    }

    @Test("Throws on empty data")
    func emptyData() async {
        let provider = PDFImportProvider()
        do {
            _ = try await provider.process(data: Data(), filename: "empty.pdf") { _ in }
            Issue.record("Expected ImportError.emptyFile")
        } catch {
            #expect(error is ImportError)
        }
    }

    /// Helper to create a PDF with a text layer for testing.
    private func createTextPDFData(text: String) -> Data? {
        let pdfData = NSMutableData()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return nil
        }

        var mediaBox = pageRect
        context.beginPage(mediaBox: &mediaBox)

        // Draw text
        let font = CTFontCreateWithName("Helvetica" as CFString, 14, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(gray: 0, alpha: 1)
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let frameSetter = CTFramesetterCreateWithAttributedString(attrString)
        let path = CGPath(rect: pageRect.insetBy(dx: 50, dy: 50), transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: 0), path, nil)
        CTFrameDraw(frame, context)

        context.endPage()
        context.closePDF()

        return pdfData as Data
    }
}

// MARK: - Filename Stem Helper Tests

@Suite("filenameStem")
struct FilenameStemTests {

    @Test("Extracts stem from filename with extension")
    func basicStem() {
        #expect(filenameStem("document.pdf") == "document")
        #expect(filenameStem("notes.md") == "notes")
        #expect(filenameStem("my-file.txt") == "my-file")
    }

    @Test("Returns full name when no extension")
    func noExtension() {
        #expect(filenameStem("README") == "README")
    }

    @Test("Handles path components")
    func pathComponents() {
        #expect(filenameStem("/path/to/document.pdf") == "document")
    }
}

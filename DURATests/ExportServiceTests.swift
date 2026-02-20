import Testing
import Foundation
@testable import DURA

@Suite("ExportService")
struct ExportServiceTests {

    @Test("Routes to correct provider and returns markdown")
    func exportMarkdown() async throws {
        let service = ExportService()
        let result = try await service.export(
            title: "Test",
            markdown: "# Test\n\nHello world",
            format: .markdown
        )

        #expect(result.mimeType == "text/markdown")
        #expect(result.filename.hasSuffix(".md"))
    }

    @Test("Routes to correct provider and returns HTML")
    func exportHTML() async throws {
        let service = ExportService()
        let result = try await service.export(
            title: "Test",
            markdown: "Hello world",
            format: .html
        )

        #expect(result.mimeType == "text/html")
        #expect(result.filename.hasSuffix(".html"))
        let content = String(data: result.data, encoding: .utf8)!
        #expect(content.contains("<!DOCTYPE html>"))
    }

    @Test("Routes to correct provider and returns PDF")
    func exportPDF() async throws {
        let service = ExportService()
        let result = try await service.export(
            title: "Test",
            markdown: "Hello world",
            format: .pdf
        )

        #expect(result.mimeType == "application/pdf")
        #expect(result.filename.hasSuffix(".pdf"))
        #expect(result.data.count > 0)
    }

    @Test("Supported formats includes all three")
    func supportedFormats() {
        let service = ExportService()
        #expect(service.supportedFormats.contains(.markdown))
        #expect(service.supportedFormats.contains(.html))
        #expect(service.supportedFormats.contains(.pdf))
    }

    @Test("Throws on empty content for all formats")
    func emptyContentThrows() async {
        let service = ExportService()
        for format in ExportFormat.allCases {
            do {
                _ = try await service.export(title: "Test", markdown: "  ", format: format)
                Issue.record("Expected ExportError.emptyContent for \(format)")
            } catch {
                #expect(error is ExportError)
            }
        }
    }
}

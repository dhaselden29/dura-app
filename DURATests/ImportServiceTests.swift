import XCTest
import SwiftData
@testable import DURA

final class ImportServiceTests: XCTestCase {

    private func makeService() throws -> DataService {
        let schema = Schema([Note.self, Notebook.self, Tag.self, Attachment.self, Bookmark.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return DataService(modelContext: context)
    }

    // MARK: - Import Tests

    @MainActor
    func testImportMarkdownCreatesNoteWithCorrectProperties() async throws {
        let ds = try makeService()
        let importService = ImportService(dataService: ds)

        // Create a temporary markdown file
        let markdown = "# Test Document\n\nThis is the body of the document."
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-import.md")
        try markdown.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let note = try await importService.importFile(at: tempURL)

        XCTAssertEqual(note.title, "Test Document")
        XCTAssertEqual(note.body, markdown)
        XCTAssertEqual(note.source, .markdown)
        XCTAssertEqual(note.originalFormat, "text/markdown")
        XCTAssertNotNil(note.sourceURL)

        // Verify attachment was created
        XCTAssertEqual(note.attachments?.count, 1)
        XCTAssertEqual(note.attachments?.first?.filename, "test-import.md")
        XCTAssertEqual(note.attachments?.first?.mimeType, "text/markdown")
    }

    @MainActor
    func testImportIntoNotebook() async throws {
        let ds = try makeService()
        let importService = ImportService(dataService: ds)
        let notebook = ds.createNotebook(name: "Research")
        try ds.save()

        let text = "Some plain text content"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-import.txt")
        try text.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let note = try await importService.importFile(at: tempURL, into: notebook)

        XCTAssertEqual(note.notebook?.name, "Research")
        XCTAssertEqual(note.source, .plainText)
    }

    @MainActor
    func testImportUnsupportedTypeThrows() async throws {
        let ds = try makeService()
        let importService = ImportService(dataService: ds)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-import.xyz")
        try "data".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            _ = try await importService.importFile(at: tempURL)
            XCTFail("Expected ImportError.unsupportedType")
        } catch is ImportError {
            // Expected
        }
    }

    @MainActor
    func testImportPlainTextUsesFirstLineAsTitle() async throws {
        let ds = try makeService()
        let importService = ImportService(dataService: ds)

        let text = "My Title Line\nSecond line\nThird line"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-import.txt")
        try text.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let note = try await importService.importFile(at: tempURL)

        XCTAssertEqual(note.title, "My Title Line")
        XCTAssertEqual(note.source, .plainText)
    }

    @MainActor
    func testSupportedContentTypesNotEmpty() throws {
        let ds = try makeService()
        let importService = ImportService(dataService: ds)

        XCTAssertFalse(importService.supportedContentTypes.isEmpty)
    }
}

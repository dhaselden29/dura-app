import Testing
import SwiftData
import Foundation
@testable import DURA

@Suite("ImportService")
struct ImportServiceTests {

    private func makeService() throws -> DataService {
        let schema = Schema([Note.self, Notebook.self, Tag.self, Attachment.self, Bookmark.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return DataService(modelContext: context)
    }

    // MARK: - Import Tests

    @Test("Import markdown creates note with correct properties")
    @MainActor
    func importMarkdownCreatesNoteWithCorrectProperties() async throws {
        let ds = try makeService()
        let importService = ImportService(dataService: ds)

        let markdown = "# Test Document\n\nThis is the body of the document."
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-import.md")
        try markdown.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let note = try await importService.importFile(at: tempURL)

        #expect(note.title == "Test Document")
        #expect(note.body == markdown)
        #expect(note.source == .markdown)
        #expect(note.noteKind == .article)
        #expect(note.isArticle == true)
        #expect(note.originalFormat == "text/markdown")
        #expect(note.sourceURL != nil)

        // Verify attachment was created
        #expect(note.attachments?.count == 1)
        #expect(note.attachments?.first?.filename == "test-import.md")
        #expect(note.attachments?.first?.mimeType == "text/markdown")
    }

    @Test("Import into notebook")
    @MainActor
    func importIntoNotebook() async throws {
        let ds = try makeService()
        let importService = ImportService(dataService: ds)
        let notebook = ds.createNotebook(name: "Research")
        try ds.save()

        let text = "Some plain text content"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-import.txt")
        try text.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let note = try await importService.importFile(at: tempURL, into: notebook)

        #expect(note.notebook?.name == "Research")
        #expect(note.source == .plainText)
        #expect(note.noteKind == .article)
    }

    @Test("Import unsupported type throws")
    @MainActor
    func importUnsupportedTypeThrows() async throws {
        let ds = try makeService()
        let importService = ImportService(dataService: ds)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-import.xyz")
        try "data".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            _ = try await importService.importFile(at: tempURL)
            Issue.record("Expected ImportError.unsupportedType")
        } catch is ImportError {
            // Expected
        }
    }

    @Test("Import plain text uses first line as title")
    @MainActor
    func importPlainTextUsesFirstLineAsTitle() async throws {
        let ds = try makeService()
        let importService = ImportService(dataService: ds)

        let text = "My Title Line\nSecond line\nThird line"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-import.txt")
        try text.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let note = try await importService.importFile(at: tempURL)

        #expect(note.title == "My Title Line")
        #expect(note.source == .plainText)
        #expect(note.noteKind == .article)
    }

    @Test("Supported content types not empty")
    @MainActor
    func supportedContentTypesNotEmpty() throws {
        let ds = try makeService()
        let importService = ImportService(dataService: ds)

        #expect(!importService.supportedContentTypes.isEmpty)
    }
}

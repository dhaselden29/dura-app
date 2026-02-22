import Testing
import SwiftData
@testable import DURA

@Suite("Highlight Annotations")
struct HighlightAnnotationTests {

    @Test("Highlight defaults to personal author")
    func highlightDefaultAuthor() {
        let h = Highlight(anchorText: "test", rangeStart: 0, rangeLength: 4, color: .yellow)
        #expect(h.author == .personal)
        #expect(h.isComment == false)
    }

    @Test("Highlight with AI author")
    func highlightAIAuthor() {
        let h = Highlight(
            anchorText: "test",
            rangeStart: 0,
            rangeLength: 4,
            color: .aiPurple,
            annotation: "AI comment",
            author: .ai,
            isComment: true
        )
        #expect(h.author == .ai)
        #expect(h.isComment == true)
        #expect(h.color == .aiPurple)
    }

    @Test("HighlightColor.userColors excludes aiPurple")
    func userColorsExcludesAI() {
        let colors = HighlightColor.userColors
        #expect(colors.count == 4)
        #expect(!colors.contains(.aiPurple))
        #expect(colors.contains(.yellow))
        #expect(colors.contains(.green))
        #expect(colors.contains(.blue))
        #expect(colors.contains(.pink))
    }

    @Test("HighlightColor.allCases includes aiPurple")
    func allCasesIncludesAI() {
        #expect(HighlightColor.allCases.count == 5)
        #expect(HighlightColor.allCases.contains(.aiPurple))
    }

    @Test("Highlight backward compatibility — new fields have defaults")
    func backwardCompatibility() {
        // Simulate old JSON without author/isComment fields
        let oldJSON = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "anchorText": "old highlight",
            "rangeStart": 10,
            "rangeLength": 13,
            "color": "yellow",
            "createdAt": 0
        }
        """
        let data = oldJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let h = try? decoder.decode(Highlight.self, from: data)
        #expect(h != nil)
        #expect(h?.author == .personal)
        #expect(h?.isComment == false)
        #expect(h?.annotation == nil)
    }

    @Test("Highlight JSON round-trip with new fields")
    func jsonRoundTrip() throws {
        let original = Highlight(
            anchorText: "text",
            rangeStart: 5,
            rangeLength: 4,
            color: .green,
            annotation: "My note",
            author: .ai,
            isComment: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Highlight.self, from: data)
        #expect(decoded.author == .ai)
        #expect(decoded.isComment == true)
        #expect(decoded.annotation == "My note")
        #expect(decoded.color == .green)
    }
}

@Suite("DataService Annotation CRUD")
struct DataServiceAnnotationTests {

    private func makeService() throws -> DataService {
        let schema = Schema([Note.self, Notebook.self, Tag.self, Attachment.self, Bookmark.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return DataService(modelContext: context)
    }

    @Test("Add annotation to note")
    func addAnnotation() throws {
        let ds = try makeService()
        let article = ds.createArticle(title: "Test")

        ds.addAnnotation(
            to: article,
            anchorText: "important",
            rangeStart: 10,
            rangeLength: 9,
            comment: "This is key"
        )

        #expect(article.highlights.count == 1)
        let h = article.highlights.first!
        #expect(h.annotation == "This is key")
        #expect(h.isComment == true)
        #expect(h.author == .personal)
    }

    @Test("Remove annotation")
    func removeAnnotation() throws {
        let ds = try makeService()
        let article = ds.createArticle(title: "Test")

        ds.addAnnotation(to: article, anchorText: "text", rangeStart: 0, rangeLength: 4, comment: "Comment")
        let id = article.highlights.first!.id

        ds.removeAnnotation(id: id, from: article)
        #expect(article.highlights.isEmpty)
    }

    @Test("Update annotation")
    func updateAnnotation() throws {
        let ds = try makeService()
        let article = ds.createArticle(title: "Test")

        ds.addAnnotation(to: article, anchorText: "text", rangeStart: 0, rangeLength: 4, comment: "Old")
        let id = article.highlights.first!.id

        ds.updateAnnotation(id: id, on: article, newComment: "New comment")
        #expect(article.highlights.first?.annotation == "New comment")
    }
}

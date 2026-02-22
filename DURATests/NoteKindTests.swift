import Testing
import SwiftData
@testable import DURA

@Suite("NoteKind")
struct NoteKindTests {

    @Test("NoteKind enum has correct cases")
    func noteKindCases() {
        #expect(NoteKind.allCases.count == 2)
        #expect(NoteKind.note.rawValue == "note")
        #expect(NoteKind.article.rawValue == "article")
    }

    @Test("NoteKind display names")
    func displayNames() {
        #expect(NoteKind.note.displayName == "Note")
        #expect(NoteKind.article.displayName == "Article")
    }

    @Test("Note defaults to .note kind")
    func noteDefaultKind() {
        let note = Note()
        #expect(note.noteKind == .note)
        #expect(note.isNote == true)
        #expect(note.isArticle == false)
        #expect(note.noteKindRaw == "note")
    }

    @Test("Note can be created as article")
    func noteArticleKind() {
        let note = Note(title: "Article", body: "Content", source: .web, kind: .article)
        #expect(note.noteKind == .article)
        #expect(note.isArticle == true)
        #expect(note.isNote == false)
        #expect(note.noteKindRaw == "article")
    }

    @Test("NoteKind computed property round-trips")
    func noteKindRoundTrip() {
        let note = Note()
        note.noteKind = .article
        #expect(note.noteKind == .article)
        #expect(note.noteKindRaw == "article")

        note.noteKind = .note
        #expect(note.noteKind == .note)
        #expect(note.noteKindRaw == "note")
    }

    @Test("Reading list defaults to false")
    func readingListDefaults() {
        let note = Note()
        #expect(note.isInReadingList == false)
        #expect(note.readingListAddedAt == nil)
    }

    @Test("Reading list fields work")
    func readingListFields() {
        let note = Note(title: "Article", kind: .article)
        note.isInReadingList = true
        note.readingListAddedAt = Date()
        #expect(note.isInReadingList == true)
        #expect(note.readingListAddedAt != nil)
    }
}

@Suite("DataService NoteKind")
struct DataServiceNoteKindTests {

    private func makeService() throws -> DataService {
        let schema = Schema([Note.self, Notebook.self, Tag.self, Attachment.self, Bookmark.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return DataService(modelContext: context)
    }

    @Test("createNote defaults to .note kind")
    func createNoteDefaultKind() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "My Note")
        #expect(note.noteKind == .note)
    }

    @Test("createNote with .article kind")
    func createNoteArticleKind() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "My Article", source: .web, kind: .article)
        #expect(note.noteKind == .article)
        #expect(note.source == .web)
    }

    @Test("createArticle convenience")
    func createArticleConvenience() throws {
        let ds = try makeService()
        let article = ds.createArticle(title: "Web Article", sourceURL: "https://example.com")
        #expect(article.noteKind == .article)
        #expect(article.sourceURL == "https://example.com")
        #expect(article.source == .web)
    }

    @Test("fetchNotes with kind filter")
    func fetchNotesKindFilter() throws {
        let ds = try makeService()
        ds.createNote(title: "Note 1")
        ds.createNote(title: "Note 2")
        ds.createNote(title: "Article 1", source: .web, kind: .article)
        try ds.save()

        let notes = try ds.fetchNotes(kind: .note)
        #expect(notes.count == 2)

        let articles = try ds.fetchNotes(kind: .article)
        #expect(articles.count == 1)
        #expect(articles.first?.title == "Article 1")

        let all = try ds.fetchNotes()
        #expect(all.count == 3)
    }

    @Test("Reading list operations")
    func readingListOperations() throws {
        let ds = try makeService()
        let article = ds.createArticle(title: "Read Later")

        ds.addToReadingList(article)
        #expect(article.isInReadingList == true)
        #expect(article.readingListAddedAt != nil)

        ds.removeFromReadingList(article)
        #expect(article.isInReadingList == false)
        #expect(article.readingListAddedAt == nil)
    }

    @Test("fetchNotes with reading list filter")
    func fetchReadingList() throws {
        let ds = try makeService()
        let a1 = ds.createArticle(title: "In List")
        ds.addToReadingList(a1)
        ds.createArticle(title: "Not In List")
        try ds.save()

        let inList = try ds.fetchNotes(kind: .article, onlyReadingList: true)
        #expect(inList.count == 1)
        #expect(inList.first?.title == "In List")
    }

    @Test("noteCount with kind filter")
    func noteCountKind() throws {
        let ds = try makeService()
        ds.createNote(title: "N1")
        ds.createNote(title: "N2")
        ds.createArticle(title: "A1")
        try ds.save()

        #expect(try ds.noteCount(kind: .note) == 2)
        #expect(try ds.noteCount(kind: .article) == 1)
        #expect(try ds.noteCount() == 3)
    }
}

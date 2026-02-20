import XCTest
import SwiftData
@testable import DURA

final class DataServiceTests: XCTestCase {

    private func makeService() throws -> DataService {
        let schema = Schema([Note.self, Notebook.self, Tag.self, Attachment.self, Bookmark.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return DataService(modelContext: context)
    }

    // MARK: - Note CRUD

    func testCreateAndFetchNotes() throws {
        let ds = try makeService()
        ds.createNote(title: "First", body: "Body 1")
        ds.createNote(title: "Second", body: "Body 2")
        try ds.save()

        let notes = try ds.fetchNotes()
        XCTAssertEqual(notes.count, 2)
    }

    func testDeleteNote() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "To Delete")
        try ds.save()

        ds.deleteNote(note)
        try ds.save()

        let notes = try ds.fetchNotes()
        XCTAssertEqual(notes.count, 0)
    }

    func testTogglePin() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "Pinnable")
        XCTAssertFalse(note.isPinned)

        ds.togglePin(note)
        XCTAssertTrue(note.isPinned)

        ds.togglePin(note)
        XCTAssertFalse(note.isPinned)
    }

    func testToggleFavorite() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "Favorite")
        XCTAssertFalse(note.isFavorite)

        ds.toggleFavorite(note)
        XCTAssertTrue(note.isFavorite)
    }

    func testDraftLifecycle() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "Blog Idea")

        ds.promoteToDraft(note)
        XCTAssertTrue(note.isDraft)
        XCTAssertEqual(note.kanbanStatus, .idea)

        ds.setKanbanStatus(.drafting, for: note)
        XCTAssertEqual(note.kanbanStatus, .drafting)

        ds.demoteFromDraft(note)
        XCTAssertFalse(note.isDraft)
        XCTAssertEqual(note.kanbanStatus, .none)
    }

    func testMoveNoteToNotebook() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "Movable")
        let nb = ds.createNotebook(name: "Target")

        ds.moveNote(note, to: nb)
        XCTAssertEqual(note.notebook?.name, "Target")

        ds.moveNote(note, to: nil)
        XCTAssertNil(note.notebook)
    }

    func testFetchWithSearchFilter() throws {
        let ds = try makeService()
        ds.createNote(title: "Swift concurrency", body: "async await")
        ds.createNote(title: "Python basics", body: "hello world")
        try ds.save()

        let results = try ds.fetchNotes(searchText: "Swift")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Swift concurrency")
    }

    func testFetchFavoritesOnly() throws {
        let ds = try makeService()
        let fav = ds.createNote(title: "Fav")
        ds.toggleFavorite(fav)
        ds.createNote(title: "Normal")
        try ds.save()

        let results = try ds.fetchNotes(onlyFavorites: true)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Fav")
    }

    func testFetchDraftsOnly() throws {
        let ds = try makeService()
        let draft = ds.createNote(title: "Draft")
        ds.promoteToDraft(draft)
        ds.createNote(title: "Regular")
        try ds.save()

        let results = try ds.fetchNotes(onlyDrafts: true)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Draft")
    }

    func testFetchByKanbanStatus() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "In Review")
        ds.promoteToDraft(note)
        ds.setKanbanStatus(.review, for: note)
        ds.createNote(title: "Normal")
        try ds.save()

        let results = try ds.fetchNotes(kanbanStatus: .review)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "In Review")
    }

    func testNoteCount() throws {
        let ds = try makeService()
        ds.createNote(title: "A")
        ds.createNote(title: "B")
        ds.createNote(title: "C")
        try ds.save()

        XCTAssertEqual(try ds.noteCount(), 3)
    }

    // MARK: - Notebook CRUD

    func testCreateAndFetchNotebooks() throws {
        let ds = try makeService()
        ds.createNotebook(name: "Research")
        ds.createNotebook(name: "Projects")
        try ds.save()

        let notebooks = try ds.fetchNotebooks()
        XCTAssertEqual(notebooks.count, 2)
    }

    func testFetchRootNotebooksOnly() throws {
        let ds = try makeService()
        let parent = ds.createNotebook(name: "Parent")
        ds.createNotebook(name: "Child", parent: parent)
        try ds.save()

        let roots = try ds.fetchNotebooks(parentOnly: true)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots.first?.name, "Parent")
    }

    func testDeleteNotebookNullifiesNotes() throws {
        let ds = try makeService()
        let nb = ds.createNotebook(name: "ToDelete")
        let note = ds.createNote(title: "Orphan", notebook: nb)
        try ds.save()

        ds.deleteNotebook(nb)
        try ds.save()

        XCTAssertNil(note.notebook)
    }

    func testMoveNotebook() throws {
        let ds = try makeService()
        let parent = ds.createNotebook(name: "Parent")
        let child = ds.createNotebook(name: "Child")

        ds.moveNotebook(child, under: parent)
        XCTAssertEqual(child.parentNotebook?.name, "Parent")
    }

    func testInboxOnDemand() throws {
        let ds = try makeService()

        let inbox1 = try ds.inboxNotebook()
        XCTAssertEqual(inbox1.name, "Inbox")

        let inbox2 = try ds.inboxNotebook()
        XCTAssertEqual(inbox1.id, inbox2.id)
    }

    // MARK: - Tag CRUD

    func testCreateAndFetchTags() throws {
        let ds = try makeService()
        ds.createTag(name: "swift")
        ds.createTag(name: "ios")
        try ds.save()

        let tags = try ds.fetchTags()
        XCTAssertEqual(tags.count, 2)
    }

    func testFindOrCreateTag() throws {
        let ds = try makeService()
        let tag1 = try ds.findOrCreateTag(name: "swift")
        try ds.save()

        let tag2 = try ds.findOrCreateTag(name: "swift")
        XCTAssertEqual(tag1.id, tag2.id)

        let tags = try ds.fetchTags()
        XCTAssertEqual(tags.count, 1)
    }

    func testAddAndRemoveTag() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "Tagged")
        let tag = ds.createTag(name: "important")

        ds.addTag(tag, to: note)
        XCTAssertEqual(note.tags?.count, 1)

        ds.addTag(tag, to: note)
        XCTAssertEqual(note.tags?.count, 1)

        ds.removeTag(tag, from: note)
        XCTAssertTrue(note.tags?.isEmpty ?? true)
    }

    func testDeleteTag() throws {
        let ds = try makeService()
        let tag = ds.createTag(name: "temp")
        try ds.save()

        ds.deleteTag(tag)
        try ds.save()

        let tags = try ds.fetchTags()
        XCTAssertEqual(tags.count, 0)
    }

    // MARK: - Attachment CRUD

    func testCreateAttachmentOnNote() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "With Attachment")
        let data = "file contents".data(using: .utf8)

        ds.createAttachment(filename: "doc.txt", data: data, mimeType: "text/plain", note: note)
        try ds.save()

        XCTAssertEqual(note.attachments?.count, 1)
        XCTAssertEqual(note.attachments?.first?.filename, "doc.txt")
    }

    func testDeleteAttachment() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "Attach")
        let att = ds.createAttachment(filename: "pic.jpg", data: nil, mimeType: "image/jpeg", note: note)
        try ds.save()

        ds.deleteAttachment(att)
        try ds.save()

        XCTAssertTrue(note.attachments?.isEmpty ?? true)
    }

    // MARK: - Bookmark CRUD

    func testCreateAndFetchBookmarks() throws {
        let ds = try makeService()
        ds.createBookmark(url: "https://apple.com", title: "Apple")
        ds.createBookmark(url: "https://swift.org", title: "Swift")
        try ds.save()

        let bookmarks = try ds.fetchBookmarks()
        XCTAssertEqual(bookmarks.count, 2)
    }

    func testFetchUnreadBookmarks() throws {
        let ds = try makeService()
        let bm = ds.createBookmark(url: "https://read.com", title: "Read")
        ds.toggleBookmarkRead(bm)
        ds.createBookmark(url: "https://unread.com", title: "Unread")
        try ds.save()

        let unread = try ds.fetchBookmarks(unreadOnly: true)
        XCTAssertEqual(unread.count, 1)
        XCTAssertEqual(unread.first?.title, "Unread")
    }

    func testToggleBookmarkRead() throws {
        let ds = try makeService()
        let bm = ds.createBookmark(url: "https://example.com", title: "Example")
        XCTAssertFalse(bm.isRead)

        ds.toggleBookmarkRead(bm)
        XCTAssertTrue(bm.isRead)

        ds.toggleBookmarkRead(bm)
        XCTAssertFalse(bm.isRead)
    }

    func testBookmarkCount() throws {
        let ds = try makeService()
        let bm = ds.createBookmark(url: "https://a.com", title: "A")
        ds.createBookmark(url: "https://b.com", title: "B")
        ds.toggleBookmarkRead(bm)
        try ds.save()

        XCTAssertEqual(try ds.bookmarkCount(), 2)
        XCTAssertEqual(try ds.bookmarkCount(unreadOnly: true), 1)
    }
}

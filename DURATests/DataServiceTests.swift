import Testing
import SwiftData
@testable import DURA

@Suite("DataService")
struct DataServiceTests {

    private func makeService() throws -> DataService {
        let schema = Schema([Note.self, Notebook.self, Tag.self, Attachment.self, Bookmark.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return DataService(modelContext: context)
    }

    // MARK: - Note CRUD

    @Test("Create and fetch notes")
    func createAndFetchNotes() throws {
        let ds = try makeService()
        ds.createNote(title: "First", body: "Body 1")
        ds.createNote(title: "Second", body: "Body 2")
        try ds.save()

        let notes = try ds.fetchNotes()
        #expect(notes.count == 2)
    }

    @Test("Delete note")
    func deleteNote() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "To Delete")
        try ds.save()

        ds.deleteNote(note)
        try ds.save()

        let notes = try ds.fetchNotes()
        #expect(notes.count == 0)
    }

    @Test("Toggle pin")
    func togglePin() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "Pinnable")
        #expect(note.isPinned == false)

        ds.togglePin(note)
        #expect(note.isPinned == true)

        ds.togglePin(note)
        #expect(note.isPinned == false)
    }

    @Test("Toggle favorite")
    func toggleFavorite() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "Favorite")
        #expect(note.isFavorite == false)

        ds.toggleFavorite(note)
        #expect(note.isFavorite == true)
    }

    @Test("Draft lifecycle")
    func draftLifecycle() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "Blog Idea")

        ds.promoteToDraft(note)
        #expect(note.isDraft == true)
        #expect(note.kanbanStatus == .idea)

        ds.setKanbanStatus(.drafting, for: note)
        #expect(note.kanbanStatus == .drafting)

        ds.demoteFromDraft(note)
        #expect(note.isDraft == false)
        #expect(note.kanbanStatus == .note)
    }

    @Test("Move note to notebook")
    func moveNoteToNotebook() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "Movable")
        let nb = ds.createNotebook(name: "Target")

        ds.moveNote(note, to: nb)
        #expect(note.notebook?.name == "Target")

        ds.moveNote(note, to: nil)
        #expect(note.notebook == nil)
    }

    @Test("Fetch with search filter")
    func fetchWithSearchFilter() throws {
        let ds = try makeService()
        ds.createNote(title: "Swift concurrency", body: "async await")
        ds.createNote(title: "Python basics", body: "hello world")
        try ds.save()

        let results = try ds.fetchNotes(searchText: "Swift")
        #expect(results.count == 1)
        #expect(results.first?.title == "Swift concurrency")
    }

    @Test("Fetch favorites only")
    func fetchFavoritesOnly() throws {
        let ds = try makeService()
        let fav = ds.createNote(title: "Fav")
        ds.toggleFavorite(fav)
        ds.createNote(title: "Normal")
        try ds.save()

        let results = try ds.fetchNotes(onlyFavorites: true)
        #expect(results.count == 1)
        #expect(results.first?.title == "Fav")
    }

    @Test("Fetch drafts only")
    func fetchDraftsOnly() throws {
        let ds = try makeService()
        let draft = ds.createNote(title: "Draft")
        ds.promoteToDraft(draft)
        ds.createNote(title: "Regular")
        try ds.save()

        let results = try ds.fetchNotes(onlyDrafts: true)
        #expect(results.count == 1)
        #expect(results.first?.title == "Draft")
    }

    @Test("Fetch by Kanban status")
    func fetchByKanbanStatus() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "In Review")
        ds.promoteToDraft(note)
        ds.setKanbanStatus(.review, for: note)
        ds.createNote(title: "Normal")
        try ds.save()

        let results = try ds.fetchNotes(kanbanStatus: .review)
        #expect(results.count == 1)
        #expect(results.first?.title == "In Review")
    }

    @Test("Note count")
    func noteCount() throws {
        let ds = try makeService()
        ds.createNote(title: "A")
        ds.createNote(title: "B")
        ds.createNote(title: "C")
        try ds.save()

        #expect(try ds.noteCount() == 3)
    }

    // MARK: - Notebook CRUD

    @Test("Create and fetch notebooks")
    func createAndFetchNotebooks() throws {
        let ds = try makeService()
        ds.createNotebook(name: "Research")
        ds.createNotebook(name: "Projects")
        try ds.save()

        let notebooks = try ds.fetchNotebooks()
        #expect(notebooks.count == 2)
    }

    @Test("Fetch root notebooks only")
    func fetchRootNotebooksOnly() throws {
        let ds = try makeService()
        let parent = ds.createNotebook(name: "Parent")
        ds.createNotebook(name: "Child", parent: parent)
        try ds.save()

        let roots = try ds.fetchNotebooks(parentOnly: true)
        #expect(roots.count == 1)
        #expect(roots.first?.name == "Parent")
    }

    @Test("Delete notebook nullifies notes")
    func deleteNotebookNullifiesNotes() throws {
        let ds = try makeService()
        let nb = ds.createNotebook(name: "ToDelete")
        let note = ds.createNote(title: "Orphan", notebook: nb)
        try ds.save()

        ds.deleteNotebook(nb)
        try ds.save()

        #expect(note.notebook == nil)
    }

    @Test("Move notebook")
    func moveNotebook() throws {
        let ds = try makeService()
        let parent = ds.createNotebook(name: "Parent")
        let child = ds.createNotebook(name: "Child")

        ds.moveNotebook(child, under: parent)
        #expect(child.parentNotebook?.name == "Parent")
    }

    @Test("Inbox on demand")
    func inboxOnDemand() throws {
        let ds = try makeService()

        let inbox1 = try ds.inboxNotebook()
        #expect(inbox1.name == "Inbox")

        let inbox2 = try ds.inboxNotebook()
        #expect(inbox1.id == inbox2.id)
    }

    // MARK: - Tag CRUD

    @Test("Create and fetch tags")
    func createAndFetchTags() throws {
        let ds = try makeService()
        ds.createTag(name: "swift")
        ds.createTag(name: "ios")
        try ds.save()

        let tags = try ds.fetchTags()
        #expect(tags.count == 2)
    }

    @Test("Find or create tag")
    func findOrCreateTag() throws {
        let ds = try makeService()
        let tag1 = try ds.findOrCreateTag(name: "swift")
        try ds.save()

        let tag2 = try ds.findOrCreateTag(name: "swift")
        #expect(tag1.id == tag2.id)

        let tags = try ds.fetchTags()
        #expect(tags.count == 1)
    }

    @Test("Add and remove tag")
    func addAndRemoveTag() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "Tagged")
        let tag = ds.createTag(name: "important")

        ds.addTag(tag, to: note)
        #expect(note.tags?.count == 1)

        ds.addTag(tag, to: note)
        #expect(note.tags?.count == 1)

        ds.removeTag(tag, from: note)
        #expect(note.tags?.isEmpty ?? true)
    }

    @Test("Delete tag")
    func deleteTag() throws {
        let ds = try makeService()
        let tag = ds.createTag(name: "temp")
        try ds.save()

        ds.deleteTag(tag)
        try ds.save()

        let tags = try ds.fetchTags()
        #expect(tags.count == 0)
    }

    // MARK: - Attachment CRUD

    @Test("Create attachment on note")
    func createAttachmentOnNote() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "With Attachment")
        let data = "file contents".data(using: .utf8)

        ds.createAttachment(filename: "doc.txt", data: data, mimeType: "text/plain", note: note)
        try ds.save()

        #expect(note.attachments?.count == 1)
        #expect(note.attachments?.first?.filename == "doc.txt")
    }

    @Test("Delete attachment")
    func deleteAttachment() throws {
        let ds = try makeService()
        let note = ds.createNote(title: "Attach")
        let att = ds.createAttachment(filename: "pic.jpg", data: nil, mimeType: "image/jpeg", note: note)
        try ds.save()

        ds.deleteAttachment(att)
        try ds.save()

        #expect(note.attachments?.isEmpty ?? true)
    }

    // MARK: - Bookmark CRUD

    @Test("Create and fetch bookmarks")
    func createAndFetchBookmarks() throws {
        let ds = try makeService()
        ds.createBookmark(url: "https://apple.com", title: "Apple")
        ds.createBookmark(url: "https://swift.org", title: "Swift")
        try ds.save()

        let bookmarks = try ds.fetchBookmarks()
        #expect(bookmarks.count == 2)
    }

    @Test("Fetch unread bookmarks")
    func fetchUnreadBookmarks() throws {
        let ds = try makeService()
        let bm = ds.createBookmark(url: "https://read.com", title: "Read")
        ds.toggleBookmarkRead(bm)
        ds.createBookmark(url: "https://unread.com", title: "Unread")
        try ds.save()

        let unread = try ds.fetchBookmarks(unreadOnly: true)
        #expect(unread.count == 1)
        #expect(unread.first?.title == "Unread")
    }

    @Test("Toggle bookmark read")
    func toggleBookmarkRead() throws {
        let ds = try makeService()
        let bm = ds.createBookmark(url: "https://example.com", title: "Example")
        #expect(bm.isRead == false)

        ds.toggleBookmarkRead(bm)
        #expect(bm.isRead == true)

        ds.toggleBookmarkRead(bm)
        #expect(bm.isRead == false)
    }

    @Test("Bookmark count")
    func bookmarkCount() throws {
        let ds = try makeService()
        let bm = ds.createBookmark(url: "https://a.com", title: "A")
        ds.createBookmark(url: "https://b.com", title: "B")
        ds.toggleBookmarkRead(bm)
        try ds.save()

        #expect(try ds.bookmarkCount() == 2)
        #expect(try ds.bookmarkCount(unreadOnly: true) == 1)
    }
}

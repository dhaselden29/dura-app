import Foundation
import Testing
import SwiftData
@testable import DURA

// MARK: - Bookmark Domain Tests

@Suite("Bookmark Domain")
struct BookmarkDomainTests {

    @Test("Standard URL extracts domain")
    func standardURL() {
        let bookmark = Bookmark(url: "https://example.com/path/to/page")
        #expect(bookmark.domain == "example.com")
    }

    @Test("Strips www prefix")
    func wwwStripping() {
        let bookmark = Bookmark(url: "https://www.apple.com/mac")
        #expect(bookmark.domain == "apple.com")
    }

    @Test("Invalid URL falls back to raw string")
    func invalidURL() {
        let bookmark = Bookmark(url: "not a valid url")
        #expect(bookmark.domain == "not a valid url")
    }

    @Test("URL with no path")
    func noPath() {
        let bookmark = Bookmark(url: "https://swift.org")
        #expect(bookmark.domain == "swift.org")
    }

    @Test("HTTP scheme extracts domain")
    func httpScheme() {
        let bookmark = Bookmark(url: "http://docs.python.org/3/tutorial")
        #expect(bookmark.domain == "docs.python.org")
    }

    @Test("Empty URL returns empty string")
    func emptyURL() {
        let bookmark = Bookmark(url: "")
        #expect(bookmark.domain == "")
    }
}

// MARK: - Bookmark DataService Tests

@Suite("Bookmark DataService")
struct BookmarkDataServiceTests {

    private func makeService() throws -> DataService {
        let schema = Schema([Note.self, Notebook.self, Tag.self, Attachment.self, Bookmark.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return DataService(modelContext: context)
    }

    @Test("Create bookmark with tags")
    func createWithTags() throws {
        let ds = try makeService()
        let tag = ds.createTag(name: "tech")
        let bookmark = ds.createBookmark(url: "https://swift.org", title: "Swift", tags: [tag])
        try ds.save()

        #expect(bookmark.tags?.count == 1)
        #expect(bookmark.tags?.first?.name == "tech")
    }

    @Test("Delete bookmark")
    func deleteBookmark() throws {
        let ds = try makeService()
        let bookmark = ds.createBookmark(url: "https://example.com", title: "Example")
        try ds.save()

        ds.deleteBookmark(bookmark)
        try ds.save()

        let bookmarks = try ds.fetchBookmarks()
        #expect(bookmarks.count == 0)
    }

    @Test("Bookmarks sort by addedAt descending")
    func sortOrder() throws {
        let ds = try makeService()
        let first = ds.createBookmark(url: "https://first.com", title: "First")
        first.addedAt = Date(timeIntervalSinceNow: -100)
        let second = ds.createBookmark(url: "https://second.com", title: "Second")
        second.addedAt = Date(timeIntervalSinceNow: -50)
        let third = ds.createBookmark(url: "https://third.com", title: "Third")
        third.addedAt = Date()
        try ds.save()

        let bookmarks = try ds.fetchBookmarks()
        #expect(bookmarks.count == 3)
        #expect(bookmarks[0].title == "Third")
        #expect(bookmarks[1].title == "Second")
        #expect(bookmarks[2].title == "First")
    }

    @Test("New bookmark defaults to unread")
    func defaultUnread() throws {
        let ds = try makeService()
        let bookmark = ds.createBookmark(url: "https://example.com", title: "New")
        try ds.save()

        #expect(bookmark.isRead == false)
    }

    @Test("Count after mixed operations")
    func countAfterMixedOps() throws {
        let ds = try makeService()
        let bm1 = ds.createBookmark(url: "https://a.com", title: "A")
        ds.createBookmark(url: "https://b.com", title: "B")
        ds.createBookmark(url: "https://c.com", title: "C")
        ds.toggleBookmarkRead(bm1) // mark A as read
        try ds.save()

        #expect(try ds.bookmarkCount() == 3)
        #expect(try ds.bookmarkCount(unreadOnly: true) == 2)

        ds.deleteBookmark(bm1)
        try ds.save()

        #expect(try ds.bookmarkCount() == 2)
        #expect(try ds.bookmarkCount(unreadOnly: true) == 2)
    }
}

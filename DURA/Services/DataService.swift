import Foundation
import SwiftData

/// Central service for all CRUD operations against the SwiftData store.
@Observable
final class DataService: @unchecked Sendable {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Save

    func save() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    // MARK: - Note CRUD

    @discardableResult
    func createNote(
        title: String = "",
        body: String = "",
        source: ImportSource = .manual,
        notebook: Notebook? = nil
    ) -> Note {
        let note = Note(title: title, body: body, source: source, notebook: notebook)
        modelContext.insert(note)
        return note
    }

    func fetchNotes(
        sortBy: NoteSortOrder = .modifiedDescending,
        notebook: Notebook? = nil,
        tag: Tag? = nil,
        kanbanStatus: KanbanStatus? = nil,
        onlyDrafts: Bool = false,
        onlyFavorites: Bool = false,
        onlyPinned: Bool = false,
        searchText: String = ""
    ) throws -> [Note] {
        var descriptor = FetchDescriptor<Note>()
        descriptor.sortBy = sortBy.sortDescriptors

        var predicates: [Predicate<Note>] = []

        if !searchText.isEmpty {
            let search = searchText
            predicates.append(#Predicate<Note> { note in
                note.title.localizedStandardContains(search) ||
                note.body.localizedStandardContains(search)
            })
        }

        if onlyFavorites {
            predicates.append(#Predicate<Note> { $0.isFavorite })
        }

        if onlyPinned {
            predicates.append(#Predicate<Note> { $0.isPinned })
        }

        if onlyDrafts {
            predicates.append(#Predicate<Note> { $0.draftMetadataData != nil })
        }

        if let status = kanbanStatus {
            let raw = status.rawValue
            predicates.append(#Predicate<Note> { $0.kanbanStatusRaw == raw })
        }

        // Combine predicates with AND
        if let combined = predicates.combinedWithAnd() {
            descriptor.predicate = combined
        }

        var results = try modelContext.fetch(descriptor)

        // Relationship-based filters (can't be expressed in #Predicate easily)
        if let notebook {
            results = results.filter { $0.notebook?.id == notebook.id }
        }
        if let tag {
            results = results.filter { note in
                note.tags?.contains(where: { $0.id == tag.id }) ?? false
            }
        }

        return results
    }

    func deleteNote(_ note: Note) {
        modelContext.delete(note)
    }

    func deleteNotes(_ notes: [Note]) {
        for note in notes {
            modelContext.delete(note)
        }
    }

    // MARK: - Note Actions

    func togglePin(_ note: Note) {
        note.isPinned.toggle()
        note.modifiedAt = Date()
    }

    func toggleFavorite(_ note: Note) {
        note.isFavorite.toggle()
        note.modifiedAt = Date()
    }

    func moveNote(_ note: Note, to notebook: Notebook?) {
        note.notebook = notebook
        note.modifiedAt = Date()
    }

    func addTag(_ tag: Tag, to note: Note) {
        if note.tags == nil { note.tags = [] }
        guard !(note.tags?.contains(where: { $0.id == tag.id }) ?? false) else { return }
        note.tags?.append(tag)
        note.modifiedAt = Date()
    }

    func removeTag(_ tag: Tag, from note: Note) {
        note.tags?.removeAll(where: { $0.id == tag.id })
        note.modifiedAt = Date()
    }

    func promoteToDraft(_ note: Note) {
        guard note.draftMetadata == nil else { return }
        note.draftMetadata = DraftMetadata(lastLocalEditAt: Date())
        note.kanbanStatus = .idea
        note.modifiedAt = Date()
    }

    func demoteFromDraft(_ note: Note) {
        note.draftMetadata = nil
        note.kanbanStatus = .note
        note.modifiedAt = Date()
    }

    func setKanbanStatus(_ status: KanbanStatus, for note: Note) {
        note.kanbanStatus = status
        note.modifiedAt = Date()
    }

    // MARK: - Notebook CRUD

    @discardableResult
    func createNotebook(
        name: String,
        icon: String? = nil,
        color: String? = nil,
        parent: Notebook? = nil
    ) -> Notebook {
        let notebook = Notebook(name: name, icon: icon, color: color, parentNotebook: parent)
        modelContext.insert(notebook)
        return notebook
    }

    func fetchNotebooks(parentOnly: Bool = false) throws -> [Notebook] {
        var descriptor = FetchDescriptor<Notebook>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        if parentOnly {
            descriptor.predicate = #Predicate<Notebook> { $0.parentNotebook == nil }
        }
        return try modelContext.fetch(descriptor)
    }

    func deleteNotebook(_ notebook: Notebook) {
        modelContext.delete(notebook)
    }

    func moveNotebook(_ notebook: Notebook, under parent: Notebook?) {
        notebook.parentNotebook = parent
    }

    // MARK: - Tag CRUD

    @discardableResult
    func createTag(name: String, color: String? = nil) -> Tag {
        let tag = Tag(name: name, color: color)
        modelContext.insert(tag)
        return tag
    }

    func fetchTags() throws -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        return try modelContext.fetch(descriptor)
    }

    func findOrCreateTag(name: String, color: String? = nil) throws -> Tag {
        let searchName = name
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { $0.name == searchName }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        return createTag(name: name, color: color)
    }

    func deleteTag(_ tag: Tag) {
        modelContext.delete(tag)
    }

    // MARK: - Attachment CRUD

    @discardableResult
    func createAttachment(
        filename: String,
        data: Data?,
        mimeType: String,
        note: Note? = nil
    ) -> Attachment {
        let attachment = Attachment(filename: filename, data: data, mimeType: mimeType, note: note)
        modelContext.insert(attachment)
        if let note {
            if note.attachments == nil { note.attachments = [] }
            note.attachments?.append(attachment)
        }
        return attachment
    }

    func deleteAttachment(_ attachment: Attachment) {
        modelContext.delete(attachment)
    }

    // MARK: - Bookmark CRUD

    @discardableResult
    func createBookmark(
        url: String,
        title: String,
        excerpt: String? = nil,
        tags: [Tag]? = nil
    ) -> Bookmark {
        let bookmark = Bookmark(url: url, title: title, excerpt: excerpt)
        bookmark.tags = tags
        modelContext.insert(bookmark)
        return bookmark
    }

    func fetchBookmarks(unreadOnly: Bool = false) throws -> [Bookmark] {
        var descriptor = FetchDescriptor<Bookmark>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        if unreadOnly {
            descriptor.predicate = #Predicate<Bookmark> { !$0.isRead }
        }
        return try modelContext.fetch(descriptor)
    }

    func toggleBookmarkRead(_ bookmark: Bookmark) {
        bookmark.isRead.toggle()
    }

    func deleteBookmark(_ bookmark: Bookmark) {
        modelContext.delete(bookmark)
    }

    // MARK: - Counts

    func noteCount() throws -> Int {
        let descriptor = FetchDescriptor<Note>()
        return try modelContext.fetchCount(descriptor)
    }

    func draftCount() throws -> Int {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.draftMetadataData != nil }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func bookmarkCount(unreadOnly: Bool = false) throws -> Int {
        var descriptor = FetchDescriptor<Bookmark>()
        if unreadOnly {
            descriptor.predicate = #Predicate<Bookmark> { !$0.isRead }
        }
        return try modelContext.fetchCount(descriptor)
    }

    // MARK: - Inbox Helpers

    /// Returns or creates the default "Inbox" notebook.
    func inboxNotebook() throws -> Notebook {
        let inboxName = "Inbox"
        let descriptor = FetchDescriptor<Notebook>(
            predicate: #Predicate { $0.name == inboxName }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        return createNotebook(name: "Inbox", icon: "tray.and.arrow.down")
    }
}

// MARK: - Sort Orders

enum NoteSortOrder: String, CaseIterable, Identifiable {
    case modifiedDescending
    case modifiedAscending
    case createdDescending
    case createdAscending
    case titleAscending
    case titleDescending

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .modifiedDescending: "Recently Modified"
        case .modifiedAscending: "Oldest Modified"
        case .createdDescending: "Recently Created"
        case .createdAscending: "Oldest Created"
        case .titleAscending: "Title (A–Z)"
        case .titleDescending: "Title (Z–A)"
        }
    }

    var sortDescriptors: [SortDescriptor<Note>] {
        switch self {
        case .modifiedDescending:
            [SortDescriptor(\.modifiedAt, order: .reverse)]
        case .modifiedAscending:
            [SortDescriptor(\.modifiedAt)]
        case .createdDescending:
            [SortDescriptor(\.createdAt, order: .reverse)]
        case .createdAscending:
            [SortDescriptor(\.createdAt)]
        case .titleAscending:
            [SortDescriptor(\.title)]
        case .titleDescending:
            [SortDescriptor(\.title, order: .reverse)]
        }
    }
}

// MARK: - Predicate Helpers

extension Array where Element == Predicate<Note> {
    func combinedWithAnd() -> Predicate<Note>? {
        guard !isEmpty else { return nil }
        return reduce(nil) { combined, next in
            guard let combined else { return next }
            return #Predicate<Note> { note in
                combined.evaluate(note) && next.evaluate(note)
            }
        }
    }
}

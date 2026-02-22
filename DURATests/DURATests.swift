import Testing
@testable import DURA

// MARK: - Model Tests (Swift Testing — no SwiftData context needed)

@Suite("Note Model")
struct NoteModelTests {

    @Test("Note initializes with correct defaults")
    func noteDefaults() {
        let note = Note()
        #expect(note.title == "")
        #expect(note.body == "")
        #expect(note.source == .manual)
        #expect(note.kanbanStatus == .note)
        #expect(note.noteKind == .note)
        #expect(note.isNote == true)
        #expect(note.isArticle == false)
        #expect(note.isInReadingList == false)
        #expect(note.isPinned == false)
        #expect(note.isFavorite == false)
        #expect(note.isBookmark == false)
        #expect(note.isDraft == false)
        #expect(note.draftMetadata == nil)
    }

    @Test("Note stores custom values")
    func noteCustomValues() {
        let note = Note(title: "Test", body: "# Hello", source: .web)
        #expect(note.title == "Test")
        #expect(note.body == "# Hello")
        #expect(note.source == .web)
    }

    @Test("Note can be promoted to draft")
    func draftPromotion() {
        let note = Note(title: "Blog Post")
        #expect(note.isDraft == false)

        note.draftMetadata = DraftMetadata()
        #expect(note.isDraft == true)
        #expect(note.draftMetadata?.wordpressStatus == .local)
    }

    @Test("Note draft metadata round-trips through JSON encoding")
    func draftMetadataRoundTrip() {
        let note = Note(title: "Post")
        var meta = DraftMetadata()
        meta.slug = "my-post"
        meta.excerpt = "A great post"
        meta.categories = ["Tech", "Swift"]
        meta.wpTags = ["iOS", "SwiftUI"]
        meta.wordpressStatus = .draft
        meta.wordpressPostId = 42

        note.draftMetadata = meta

        let decoded = note.draftMetadata
        #expect(decoded?.slug == "my-post")
        #expect(decoded?.excerpt == "A great post")
        #expect(decoded?.categories == ["Tech", "Swift"])
        #expect(decoded?.wpTags == ["iOS", "SwiftUI"])
        #expect(decoded?.wordpressStatus == .draft)
        #expect(decoded?.wordpressPostId == 42)
    }

    @Test("KanbanStatus computed property round-trips")
    func kanbanRoundTrip() {
        let note = Note()
        note.kanbanStatus = .drafting
        #expect(note.kanbanStatus == .drafting)
        #expect(note.kanbanStatusRaw == "drafting")
    }

    @Test("ImportSource computed property round-trips")
    func importSourceRoundTrip() {
        let note = Note()
        note.source = .pdf
        #expect(note.source == .pdf)
        #expect(note.sourceRaw == "pdf")
    }
}

@Suite("KanbanStatus")
struct KanbanStatusTests {

    @Test("Board statuses exclude .none")
    func boardStatuses() {
        let statuses = KanbanStatus.boardStatuses
        #expect(!statuses.contains(.none))
        #expect(statuses.count == 6)
    }

    @Test("All cases have display names")
    func displayNames() {
        for status in KanbanStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
    }

    @Test("All cases have icon names")
    func iconNames() {
        for status in KanbanStatus.allCases {
            #expect(!status.iconName.isEmpty)
        }
    }
}

@Suite("Block")
struct BlockTests {

    @Test("Block initializes with defaults")
    func blockDefaults() {
        let block = Block()
        #expect(block.type == .paragraph)
        #expect(block.content == "")
        #expect(block.metadata == nil)
        #expect(block.children == nil)
    }

    @Test("Block with all properties")
    func blockFull() {
        let child = Block(type: .paragraph, content: "Nested")
        let block = Block(
            type: .toggle,
            content: "Details",
            metadata: ["collapsed": "true"],
            children: [child]
        )
        #expect(block.type == .toggle)
        #expect(block.content == "Details")
        #expect(block.metadata?["collapsed"] == "true")
        #expect(block.children?.count == 1)
    }

    @Test("BlockType display names are non-empty")
    func blockTypeNames() {
        let types: [BlockType] = [
            .paragraph, .heading(level: 1), .image, .codeBlock,
            .quote, .bulletList, .numberedList, .checklist,
            .toggle, .divider, .embed, .audio
        ]
        for type in types {
            #expect(!type.displayName.isEmpty)
            #expect(!type.iconName.isEmpty)
        }
    }
}

@Suite("Notebook Model")
struct NotebookTests {

    @Test("Notebook initializes correctly")
    func notebookInit() {
        let nb = Notebook(name: "Research", icon: "magnifyingglass", color: "#FF0000")
        #expect(nb.name == "Research")
        #expect(nb.icon == "magnifyingglass")
        #expect(nb.color == "#FF0000")
        #expect(nb.sortOrder == 0)
    }

    @Test("Notebook supports parent-child")
    func notebookNesting() {
        let parent = Notebook(name: "Projects")
        let child = Notebook(name: "iOS", parentNotebook: parent)
        #expect(child.parentNotebook?.name == "Projects")
    }
}

@Suite("Tag Model")
struct TagTests {
    @Test("Tag initializes correctly")
    func tagInit() {
        let tag = Tag(name: "swift", color: "#F05138")
        #expect(tag.name == "swift")
        #expect(tag.color == "#F05138")
    }
}

@Suite("Attachment Model")
struct AttachmentTests {
    @Test("Attachment initializes correctly")
    func attachmentInit() {
        let data = "hello".data(using: .utf8)
        let attachment = Attachment(filename: "test.txt", data: data, mimeType: "text/plain")
        #expect(attachment.filename == "test.txt")
        #expect(attachment.mimeType == "text/plain")
        #expect(attachment.data == data)
        #expect(attachment.ocrText == nil)
    }
}

@Suite("Bookmark Model")
struct BookmarkTests {
    @Test("Bookmark initializes correctly")
    func bookmarkInit() {
        let bm = Bookmark(url: "https://example.com", title: "Example", excerpt: "A great site")
        #expect(bm.url == "https://example.com")
        #expect(bm.title == "Example")
        #expect(bm.excerpt == "A great site")
        #expect(bm.isRead == false)
    }
}

@Suite("NoteSortOrder")
struct NoteSortOrderTests {
    @Test("All sort orders have display names")
    func displayNames() {
        for order in NoteSortOrder.allCases {
            #expect(!order.displayName.isEmpty)
        }
    }

    @Test("All sort orders produce sort descriptors")
    func sortDescriptors() {
        for order in NoteSortOrder.allCases {
            #expect(!order.sortDescriptors.isEmpty)
        }
    }
}

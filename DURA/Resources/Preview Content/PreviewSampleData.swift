import SwiftData

@MainActor
let previewContainer: ModelContainer = {
    let schema = Schema([
        Note.self,
        Notebook.self,
        Tag.self,
        Attachment.self,
        Bookmark.self,
        PodcastClip.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    // Sample data for previews
    let inbox = Notebook(name: "Inbox", icon: "tray.and.arrow.down")
    container.mainContext.insert(inbox)

    let research = Notebook(name: "Research", icon: "magnifyingglass")
    container.mainContext.insert(research)

    let sampleNote = Note(
        title: "Welcome to DURA",
        body: "# Welcome\n\nThis is your first note. Start writing!",
        notebook: inbox
    )
    container.mainContext.insert(sampleNote)

    let draftNote = Note(
        title: "My First Blog Post",
        body: "## Introduction\n\nThis is a draft blog post.",
        notebook: research
    )
    draftNote.kanbanStatus = .drafting
    draftNote.draftMetadata = DraftMetadata()
    container.mainContext.insert(draftNote)

    let tag = Tag(name: "swift", color: "#F05138")
    container.mainContext.insert(tag)

    let readingTag = Tag(name: "reading", color: "#007AFF")
    container.mainContext.insert(readingTag)

    let aiTag = Tag(name: "ai", color: "#AF52DE")
    container.mainContext.insert(aiTag)

    // Sample bookmarks
    let bookmark1 = Bookmark(
        url: "https://developer.apple.com/documentation/swiftdata",
        title: "SwiftData Documentation"
    )
    bookmark1.tags = [tag]
    container.mainContext.insert(bookmark1)

    let bookmark2 = Bookmark(
        url: "https://www.swiftbysundell.com/articles/the-power-of-key-paths-in-swift",
        title: "The Power of Key Paths in Swift"
    )
    bookmark2.tags = [tag, readingTag]
    container.mainContext.insert(bookmark2)

    let bookmark3 = Bookmark(
        url: "https://openai.com/blog",
        title: ""
    )
    bookmark3.isRead = true
    bookmark3.tags = [aiTag]
    container.mainContext.insert(bookmark3)

    // Sample podcast clips
    let resolvedClip = PodcastClip(
        episodeTitle: "Understanding Swift Concurrency",
        podcastName: "Swift by Sundell",
        playbackPosition: 1234,
        clipDuration: 60
    )
    resolvedClip.processingStatus = .resolved
    resolvedClip.feedURL = "https://swiftbysundell.com/feed.rss"
    container.mainContext.insert(resolvedClip)

    let pendingClip = PodcastClip(
        episodeTitle: "The Future of AI Assistants",
        podcastName: "Lex Fridman Podcast",
        playbackPosition: 3600,
        clipDuration: 120
    )
    container.mainContext.insert(pendingClip)

    let failedClip = PodcastClip(
        episodeTitle: "Episode 42",
        podcastName: "Unknown Podcast",
        playbackPosition: 500,
        clipDuration: 60
    )
    failedClip.processingStatus = .failed
    container.mainContext.insert(failedClip)

    return container
}()

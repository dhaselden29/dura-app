import SwiftData

@MainActor
let previewContainer: ModelContainer = {
    let schema = Schema([
        Note.self,
        Notebook.self,
        Tag.self,
        Attachment.self,
        Bookmark.self
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

    return container
}()

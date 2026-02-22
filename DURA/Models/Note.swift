import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var sourceRaw: String = ImportSource.manual.rawValue
    var sourceURL: String?
    var originalFormat: String?
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var isPinned: Bool = false
    var isFavorite: Bool = false
    var isBookmark: Bool = false
    var kanbanStatusRaw: String = KanbanStatus.note.rawValue
    var draftMetadataData: Data?
    var highlightsData: Data?

    @Relationship(inverse: \Tag.notes)
    var tags: [Tag]? = []

    @Relationship(inverse: \Notebook.notes)
    var notebook: Notebook?

    @Relationship(deleteRule: .cascade, inverse: \Attachment.note)
    var attachments: [Attachment]? = []

    var podcastClip: PodcastClip?

    // Wikilink references stored as an array of note IDs (serialized).
    // Bidirectional linking resolved at query time.
    var linkedNoteIDs: [String]? = []

    init(
        title: String = "",
        body: String = "",
        source: ImportSource = .manual,
        notebook: Notebook? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.sourceRaw = source.rawValue
        self.notebook = notebook
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - Computed Properties

    var source: ImportSource {
        get { ImportSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var kanbanStatus: KanbanStatus {
        get {
            let status = KanbanStatus(rawValue: kanbanStatusRaw) ?? .note
            return status == .none ? .note : status
        }
        set { kanbanStatusRaw = newValue.rawValue }
    }

    var draftMetadata: DraftMetadata? {
        get {
            guard let data = draftMetadataData else { return nil }
            return try? JSONDecoder().decode(DraftMetadata.self, from: data)
        }
        set {
            draftMetadataData = try? JSONEncoder().encode(newValue)
        }
    }

    var highlights: [Highlight] {
        get {
            guard let data = highlightsData else { return [] }
            return (try? JSONDecoder().decode([Highlight].self, from: data)) ?? []
        }
        set {
            highlightsData = try? JSONEncoder().encode(newValue)
        }
    }

    var isDraft: Bool {
        draftMetadata != nil
    }
}

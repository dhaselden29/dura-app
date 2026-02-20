import Foundation

/// WordPress publishing status for a draft.
enum DraftStatus: String, Codable, CaseIterable, Identifiable {
    case local
    case uploading
    case draft
    case scheduled
    case published

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .local: "Local"
        case .uploading: "Uploading"
        case .draft: "WP Draft"
        case .scheduled: "Scheduled"
        case .published: "Published"
        }
    }
}

/// Blog draft metadata embedded in a Note. When non-nil, the note is a blog draft.
struct DraftMetadata: Codable, Hashable {
    var wordpressPostId: Int?
    var wordpressStatus: DraftStatus = .local
    var slug: String?
    var excerpt: String?
    var categories: [String]?
    var wpTags: [String]?
    var featuredImageId: UUID?
    var scheduledDate: Date?
    var lastPublishedAt: Date?
    var lastLocalEditAt: Date?
}

import Foundation

/// Distinguishes user-created notes from imported articles.
enum NoteKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case note
    case article

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .note: "Note"
        case .article: "Article"
        }
    }

    var iconName: String {
        switch self {
        case .note: "doc.text"
        case .article: "doc.richtext"
        }
    }
}

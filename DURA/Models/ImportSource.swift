import Foundation

/// Identifies how a note was originally created or imported.
enum ImportSource: String, Codable, CaseIterable, Identifiable {
    case manual
    case onenote
    case appleNotes
    case goodnotes
    case pdf
    case web
    case kindle
    case email
    case markdown
    case plainText
    case rtf
    case image

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: "Manual"
        case .onenote: "OneNote"
        case .appleNotes: "Apple Notes"
        case .goodnotes: "GoodNotes"
        case .pdf: "PDF"
        case .web: "Web"
        case .kindle: "Kindle"
        case .email: "Email"
        case .markdown: "Markdown"
        case .plainText: "Plain Text"
        case .rtf: "RTF"
        case .image: "Image"
        }
    }
}

import Foundation

/// Tracks the editorial workflow stage of a note/draft on the Kanban board.
enum KanbanStatus: String, Codable, CaseIterable, Identifiable {
    case none
    case note
    case idea
    case researching
    case drafting
    case review
    case published

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .note: "Note"
        case .idea: "Idea"
        case .researching: "Researching"
        case .drafting: "Drafting"
        case .review: "Review"
        case .published: "Published"
        }
    }

    var iconName: String {
        switch self {
        case .none: "circle.dashed"
        case .note: "doc.text"
        case .idea: "lightbulb"
        case .researching: "magnifyingglass"
        case .drafting: "pencil"
        case .review: "eye"
        case .published: "checkmark.circle.fill"
        }
    }

    /// Only statuses shown as Kanban columns (excludes .none and .note).
    static var boardStatuses: [KanbanStatus] {
        allCases.filter { $0 != .none && $0 != .note }
    }
}

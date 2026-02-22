import Foundation
import SwiftUI

/// Identifies who created a highlight or annotation.
enum HighlightAuthor: String, Codable, CaseIterable, Sendable {
    case personal
    case ai
}

struct Highlight: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var anchorText: String
    var rangeStart: Int
    var rangeLength: Int
    var color: HighlightColor
    var annotation: String?
    var author: HighlightAuthor = .personal
    var isComment: Bool = false
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        anchorText: String,
        rangeStart: Int,
        rangeLength: Int,
        color: HighlightColor,
        annotation: String? = nil,
        author: HighlightAuthor = .personal,
        isComment: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.anchorText = anchorText
        self.rangeStart = rangeStart
        self.rangeLength = rangeLength
        self.color = color
        self.annotation = annotation
        self.author = author
        self.isComment = isComment
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        anchorText = try container.decode(String.self, forKey: .anchorText)
        rangeStart = try container.decode(Int.self, forKey: .rangeStart)
        rangeLength = try container.decode(Int.self, forKey: .rangeLength)
        color = try container.decode(HighlightColor.self, forKey: .color)
        annotation = try container.decodeIfPresent(String.self, forKey: .annotation)
        author = try container.decodeIfPresent(HighlightAuthor.self, forKey: .author) ?? .personal
        isComment = try container.decodeIfPresent(Bool.self, forKey: .isComment) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

enum HighlightColor: String, Codable, CaseIterable, Sendable {
    case yellow, green, blue, pink, aiPurple

    var displayName: String {
        switch self {
        case .aiPurple: "AI Purple"
        default: rawValue.capitalized
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .pink: .pink
        case .aiPurple: .purple
        }
    }

    /// Colors available for user-created highlights (excludes AI-only colors).
    static var userColors: [HighlightColor] {
        [.yellow, .green, .blue, .pink]
    }

    #if canImport(AppKit)
    var nsColor: NSColor {
        switch self {
        case .yellow: NSColor.systemYellow.withAlphaComponent(0.35)
        case .green: NSColor.systemGreen.withAlphaComponent(0.35)
        case .blue: NSColor.systemBlue.withAlphaComponent(0.35)
        case .pink: NSColor.systemPink.withAlphaComponent(0.35)
        case .aiPurple: NSColor.systemPurple.withAlphaComponent(0.35)
        }
    }
    #elseif canImport(UIKit)
    var uiColor: UIColor {
        switch self {
        case .yellow: UIColor.systemYellow.withAlphaComponent(0.35)
        case .green: UIColor.systemGreen.withAlphaComponent(0.35)
        case .blue: UIColor.systemBlue.withAlphaComponent(0.35)
        case .pink: UIColor.systemPink.withAlphaComponent(0.35)
        case .aiPurple: UIColor.systemPurple.withAlphaComponent(0.35)
        }
    }
    #endif
}

import Foundation
import SwiftUI

struct Highlight: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var anchorText: String
    var rangeStart: Int
    var rangeLength: Int
    var color: HighlightColor
    var annotation: String?
    var createdAt: Date = Date()
}

enum HighlightColor: String, Codable, CaseIterable, Sendable {
    case yellow, green, blue, pink

    var displayName: String {
        rawValue.capitalized
    }

    var swiftUIColor: Color {
        switch self {
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .pink: .pink
        }
    }

    #if canImport(AppKit)
    var nsColor: NSColor {
        switch self {
        case .yellow: NSColor.systemYellow.withAlphaComponent(0.35)
        case .green: NSColor.systemGreen.withAlphaComponent(0.35)
        case .blue: NSColor.systemBlue.withAlphaComponent(0.35)
        case .pink: NSColor.systemPink.withAlphaComponent(0.35)
        }
    }
    #elseif canImport(UIKit)
    var uiColor: UIColor {
        switch self {
        case .yellow: UIColor.systemYellow.withAlphaComponent(0.35)
        case .green: UIColor.systemGreen.withAlphaComponent(0.35)
        case .blue: UIColor.systemBlue.withAlphaComponent(0.35)
        case .pink: UIColor.systemPink.withAlphaComponent(0.35)
        }
    }
    #endif
}

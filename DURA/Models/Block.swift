import Foundation

/// The type of content a block represents.
enum BlockType: Codable, Hashable {
    case paragraph
    case heading(level: Int)
    case image
    case codeBlock
    case quote
    case bulletList
    case numberedList
    case checklist
    case toggle
    case divider
    case embed
    case audio

    var displayName: String {
        switch self {
        case .paragraph: "Paragraph"
        case .heading(let level): "Heading \(level)"
        case .image: "Image"
        case .codeBlock: "Code Block"
        case .quote: "Quote"
        case .bulletList: "Bullet List"
        case .numberedList: "Numbered List"
        case .checklist: "Checklist"
        case .toggle: "Toggle"
        case .divider: "Divider"
        case .embed: "Embed"
        case .audio: "Audio"
        }
    }

    var iconName: String {
        switch self {
        case .paragraph: "text.alignleft"
        case .heading: "textformat.size"
        case .image: "photo"
        case .codeBlock: "chevron.left.forwardslash.chevron.right"
        case .quote: "text.quote"
        case .bulletList: "list.bullet"
        case .numberedList: "list.number"
        case .checklist: "checklist"
        case .toggle: "chevron.right"
        case .divider: "minus"
        case .embed: "link"
        case .audio: "waveform"
        }
    }
}

/// A single content block within a note. Value type, serialized within Note.body as Markdown.
struct Block: Identifiable, Codable, Hashable {
    var id: UUID
    var type: BlockType
    var content: String
    var metadata: [String: String]?
    var children: [Block]?

    init(
        id: UUID = UUID(),
        type: BlockType = .paragraph,
        content: String = "",
        metadata: [String: String]? = nil,
        children: [Block]? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.metadata = metadata
        self.children = children
    }
}

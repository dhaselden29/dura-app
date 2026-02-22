import Foundation

/// Actions triggered by toolbar formatting buttons.
enum FormatAction: Equatable {
    case bold
    case italic
    case inlineCode
    case strikethrough

    var wrapper: String {
        switch self {
        case .bold: return "**"
        case .italic: return "_"
        case .inlineCode: return "`"
        case .strikethrough: return "~~"
        }
    }
}

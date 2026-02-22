import SwiftUI

// MARK: - Reader Theme

enum ReaderTheme: String, CaseIterable, Sendable {
    case light, sepia, dark

    var displayName: String {
        switch self {
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }

    var iconName: String {
        switch self {
        case .light: "sun.max"
        case .sepia: "cup.and.saucer"
        case .dark: "moon"
        }
    }

    var cssBackground: String {
        switch self {
        case .light: "#FFFFFF"
        case .sepia: "#F4ECD8"
        case .dark: "#1E1E1E"
        }
    }

    var cssTextColor: String {
        switch self {
        case .light: "#333333"
        case .sepia: "#5B4636"
        case .dark: "#D4D4D4"
        }
    }

    #if canImport(AppKit)
    var backgroundColor: NSColor {
        switch self {
        case .light: .clear
        case .sepia: NSColor(red: 0.957, green: 0.925, blue: 0.847, alpha: 1) // #F4ECD8
        case .dark: NSColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1)  // #1E1E1E
        }
    }

    var textColor: NSColor {
        switch self {
        case .light: .labelColor
        case .sepia: NSColor(red: 0.357, green: 0.275, blue: 0.212, alpha: 1) // #5B4636
        case .dark: NSColor(red: 0.831, green: 0.831, blue: 0.831, alpha: 1)  // #D4D4D4
        }
    }

    var swiftUIBackground: Color {
        switch self {
        case .light: .clear
        case .sepia: Color(red: 0.957, green: 0.925, blue: 0.847)
        case .dark: Color(red: 0.118, green: 0.118, blue: 0.118)
        }
    }

    var swiftUITextColor: Color {
        switch self {
        case .light: Color(.labelColor)
        case .sepia: Color(red: 0.357, green: 0.275, blue: 0.212)
        case .dark: Color(red: 0.831, green: 0.831, blue: 0.831)
        }
    }
    #elseif canImport(UIKit)
    var backgroundColor: UIColor {
        switch self {
        case .light: .systemBackground
        case .sepia: UIColor(red: 0.957, green: 0.925, blue: 0.847, alpha: 1)
        case .dark: UIColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1)
        }
    }

    var textColor: UIColor {
        switch self {
        case .light: .label
        case .sepia: UIColor(red: 0.357, green: 0.275, blue: 0.212, alpha: 1)
        case .dark: UIColor(red: 0.831, green: 0.831, blue: 0.831, alpha: 1)
        }
    }

    var swiftUIBackground: Color {
        switch self {
        case .light: Color(.systemBackground)
        case .sepia: Color(red: 0.957, green: 0.925, blue: 0.847)
        case .dark: Color(red: 0.118, green: 0.118, blue: 0.118)
        }
    }

    var swiftUITextColor: Color {
        switch self {
        case .light: Color(.label)
        case .sepia: Color(red: 0.357, green: 0.275, blue: 0.212)
        case .dark: Color(red: 0.831, green: 0.831, blue: 0.831)
        }
    }
    #endif
}

// MARK: - Reader Font

enum ReaderFont: String, CaseIterable, Sendable {
    case system, serif, mono, openDyslexic

    var displayName: String {
        switch self {
        case .system: "System"
        case .serif: "Serif"
        case .mono: "Mono"
        case .openDyslexic: "OpenDyslexic"
        }
    }

    var cssValue: String {
        switch self {
        case .system: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif"
        case .serif: "'New York', Georgia, 'Times New Roman', serif"
        case .mono: "'SF Mono', Menlo, Consolas, monospace"
        case .openDyslexic: "'OpenDyslexic', sans-serif"
        }
    }

    #if canImport(AppKit)
    func nsFont(size: CGFloat) -> NSFont {
        nsFont(size: size, weight: .regular)
    }

    func nsFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        switch self {
        case .system:
            return NSFont.systemFont(ofSize: size, weight: weight)
        case .serif:
            let base = NSFont(name: "New York", size: size)
                ?? NSFont(name: "Georgia", size: size)
                ?? NSFont.systemFont(ofSize: size, weight: weight)
            if weight == .bold || weight == .semibold || weight == .heavy {
                return NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
            }
            return base
        case .mono:
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .openDyslexic:
            let base = NSFont(name: "OpenDyslexic", size: size)
                ?? NSFont.systemFont(ofSize: size, weight: weight)
            if weight == .bold || weight == .semibold || weight == .heavy {
                return NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
            }
            return base
        }
    }
    #elseif canImport(UIKit)
    func uiFont(size: CGFloat) -> UIFont {
        switch self {
        case .system:
            return UIFont.systemFont(ofSize: size, weight: .regular)
        case .serif:
            return UIFont(name: "Georgia", size: size)
                ?? UIFont.systemFont(ofSize: size)
        case .mono:
            return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .openDyslexic:
            return UIFont(name: "OpenDyslexic", size: size)
                ?? UIFont.systemFont(ofSize: size)
        }
    }
    #endif
}

// MARK: - AppStorage Keys & Defaults

enum ReaderDefaults {
    static let fontSize: Double = 17
    static let lineSpacing: Double = 6
    static let maxWidth: Double = 700
    static let theme: String = ReaderTheme.light.rawValue
    static let font: String = ReaderFont.system.rawValue
}

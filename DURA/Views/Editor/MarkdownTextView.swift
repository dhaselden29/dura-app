import SwiftUI

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

// MARK: - macOS Implementation

#if os(macOS)
import AppKit

/// NSTextView subclass that intercepts keyboard shortcuts for markdown formatting.
final class EditorTextView: NSTextView {
    /// Callback for highlight creation from context menu.
    var onHighlightRequest: ((NSRange, HighlightColor) -> Void)?

    /// Called by the coordinator to apply a formatting action.
    func applyFormat(_ action: FormatAction) {
        wrapSelection(with: action.wrapper)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        let range = selectedRange()

        if range.length > 0 {
            menu.insertItem(.separator(), at: 0)

            let highlightMenu = NSMenu()
            for color in HighlightColor.allCases {
                let item = NSMenuItem(
                    title: color.displayName,
                    action: #selector(highlightWithColor(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = color
                item.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: color.displayName)
                item.image?.isTemplate = false
                // Tint the circle to match the highlight color
                let config = NSImage.SymbolConfiguration(paletteColors: [NSColor(color.swiftUIColor)])
                item.image = item.image?.withSymbolConfiguration(config)
                highlightMenu.addItem(item)
            }

            let highlightItem = NSMenuItem(title: "Highlight", action: nil, keyEquivalent: "")
            highlightItem.submenu = highlightMenu
            highlightItem.image = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "Highlight")
            menu.insertItem(highlightItem, at: 0)
        }

        return menu
    }

    @objc private func highlightWithColor(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? HighlightColor else { return }
        let range = selectedRange()
        guard range.length > 0 else { return }
        onHighlightRequest?(range, color)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+B → bold
        if flags == .command, event.charactersIgnoringModifiers == "b" {
            wrapSelection(with: "**")
            return
        }

        // Cmd+I → italic
        if flags == .command, event.charactersIgnoringModifiers == "i" {
            wrapSelection(with: "_")
            return
        }

        // Cmd+E → inline code
        if flags == .command, event.charactersIgnoringModifiers == "e" {
            wrapSelection(with: "`")
            return
        }

        // Cmd+Shift+X → strikethrough
        if flags == [.command, .shift], event.charactersIgnoringModifiers == "x" {
            wrapSelection(with: "~~")
            return
        }

        // Tab → insert 4 spaces
        if event.keyCode == 48 && flags.isEmpty {
            insertText("    ", replacementRange: selectedRange())
            return
        }

        // Space → scroll page down (when not editing, i.e. read-only mode)
        if event.keyCode == 49 && flags.isEmpty && !isEditable {
            enclosingScrollView?.pageDown(nil)
            return
        }

        // Shift+Space → scroll page up (when not editing)
        if event.keyCode == 49 && flags == .shift && !isEditable {
            enclosingScrollView?.pageUp(nil)
            return
        }

        super.keyDown(with: event)
    }

    /// Wraps the current selection with the given delimiter, or inserts empty
    /// delimiters at the cursor. Uses NSTextView undo support.
    private func wrapSelection(with wrapper: String) {
        let range = selectedRange()
        let currentText = (string as NSString)

        let selectedText = range.length > 0
            ? currentText.substring(with: range)
            : ""

        let replacement = "\(wrapper)\(selectedText)\(wrapper)"

        if shouldChangeText(in: range, replacementString: replacement) {
            replaceCharacters(in: range, with: replacement)
            didChangeText()

            // Place cursor after the opening wrapper if no selection,
            // or select the wrapped text if there was a selection.
            if selectedText.isEmpty {
                let cursorPos = range.location + wrapper.utf16.count
                setSelectedRange(NSRange(location: cursorPos, length: 0))
            } else {
                let selStart = range.location + wrapper.utf16.count
                setSelectedRange(NSRange(location: selStart, length: selectedText.utf16.count))
            }
        }
    }
}

/// SwiftUI wrapper for NSTextView-based markdown editing.
struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var formatAction: FormatAction?
    @Binding var requestFocus: Bool
    var useProportionalFont: Bool = false
    var fontSize: CGFloat = 17
    var lineSpacing: CGFloat = 6
    var fontFamily: ReaderFont = .system
    var maxWidth: CGFloat = 700
    var theme: ReaderTheme = .light
    var highlights: [Highlight] = []
    var onHighlightCreated: ((Highlight) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = EditorTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        let resolvedFont = resolveFont()
        textView.font = resolvedFont
        textView.textColor = theme.textColor
        textView.backgroundColor = theme.backgroundColor
        textView.drawsBackground = theme != .light
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.defaultParagraphStyle = makeParagraphStyle()

        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        // Wire up highlight creation
        let coordinator = context.coordinator
        textView.onHighlightRequest = { range, color in
            let bodyNS = textView.string as NSString
            let anchorText = bodyNS.substring(with: range)
            let highlight = Highlight(
                anchorText: anchorText,
                rangeStart: range.location,
                rangeLength: range.length,
                color: color
            )
            coordinator.parent.onHighlightCreated?(highlight)
        }

        scrollView.documentView = textView

        // Set initial text
        textView.string = text
        applyHighlights(to: textView)

        return scrollView
    }

    private func resolveFont() -> NSFont {
        if useProportionalFont {
            return fontFamily.nsFont(size: fontSize)
        } else {
            return ReaderFont.mono.nsFont(size: fontSize)
        }
    }

    private func makeParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        return style
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorTextView else { return }

        // Update theme colors
        textView.textColor = theme.textColor
        textView.backgroundColor = theme.backgroundColor
        textView.drawsBackground = theme != .light

        // Update max width via text container inset for centering
        let viewWidth = scrollView.contentSize.width
        if maxWidth < viewWidth {
            let horizontalInset = max(8, (viewWidth - maxWidth) / 2)
            textView.textContainerInset = NSSize(width: horizontalInset, height: 8)
        } else {
            textView.textContainerInset = NSSize(width: 8, height: 8)
        }

        // Switch font when parameters change
        let expectedFont = resolveFont()
        let newStyle = makeParagraphStyle()
        if textView.font?.fontName != expectedFont.fontName
            || textView.font?.pointSize != expectedFont.pointSize
            || textView.defaultParagraphStyle != newStyle
        {
            let selectedRanges = textView.selectedRanges
            textView.font = expectedFont
            textView.defaultParagraphStyle = newStyle
            // Re-apply attributes to existing text
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            if fullRange.length > 0 {
                textView.textStorage?.addAttribute(.font, value: expectedFont, range: fullRange)
                textView.textStorage?.addAttribute(.paragraphStyle, value: newStyle, range: fullRange)
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.textColor, range: fullRange)
            }
            textView.selectedRanges = selectedRanges
        }

        // Sync text from binding → view (avoid loop via guard)
        if !context.coordinator.isUpdating && textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            // Re-apply font after setting string
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            if fullRange.length > 0 {
                textView.textStorage?.addAttribute(.font, value: expectedFont, range: fullRange)
                textView.textStorage?.addAttribute(.paragraphStyle, value: newStyle, range: fullRange)
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.textColor, range: fullRange)
            }
            textView.selectedRanges = selectedRanges
        }

        // Apply highlights
        applyHighlights(to: textView)

        // Apply pending toolbar format action
        if let action = formatAction {
            DispatchQueue.main.async {
                formatAction = nil
                textView.applyFormat(action)
            }
        }

        // Handle focus request
        if requestFocus {
            DispatchQueue.main.async {
                requestFocus = false
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    private func applyHighlights(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard fullRange.length > 0 else { return }

        // Remove existing highlight backgrounds
        textStorage.removeAttribute(.backgroundColor, range: fullRange)

        // Apply each highlight
        let bodyNS = textView.string as NSString
        for highlight in highlights {
            var range = NSRange(location: highlight.rangeStart, length: highlight.rangeLength)

            // Validate range is within bounds
            if range.location + range.length > bodyNS.length {
                // Try to relocate using anchor text
                let searchRange = bodyNS.range(of: highlight.anchorText)
                if searchRange.location != NSNotFound {
                    range = searchRange
                } else {
                    continue
                }
            }

            textStorage.addAttribute(.backgroundColor, value: highlight.color.nsColor, range: range)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MarkdownTextView
        weak var textView: EditorTextView?
        var isUpdating = false

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            parent.text = textView.string
            isUpdating = false
        }
    }
}

// MARK: - iOS Implementation

#elseif os(iOS)
import UIKit

/// SwiftUI wrapper for UITextView-based markdown editing on iOS.
struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var formatAction: FormatAction?
    @Binding var requestFocus: Bool
    var useProportionalFont: Bool = false
    var fontSize: CGFloat = 17
    var lineSpacing: CGFloat = 6
    var fontFamily: ReaderFont = .system
    var maxWidth: CGFloat = 700
    var theme: ReaderTheme = .light
    var highlights: [Highlight] = []
    var onHighlightCreated: ((Highlight) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = resolveFont()
        textView.textColor = theme.textColor
        textView.backgroundColor = theme.backgroundColor
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        textView.text = text
        return textView
    }

    private func resolveFont() -> UIFont {
        if useProportionalFont {
            return fontFamily.uiFont(size: fontSize)
        } else {
            return ReaderFont.mono.uiFont(size: fontSize)
        }
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Update theme colors
        textView.textColor = theme.textColor
        textView.backgroundColor = theme.backgroundColor

        // Update max width via text container inset
        let viewWidth = textView.bounds.width
        if maxWidth < viewWidth && viewWidth > 0 {
            let horizontalInset = max(8, (viewWidth - maxWidth) / 2)
            textView.textContainerInset = UIEdgeInsets(top: 8, left: horizontalInset, bottom: 8, right: horizontalInset)
        } else {
            textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        }

        // Switch font when parameters change
        let expectedFont = resolveFont()
        if textView.font != expectedFont {
            textView.font = expectedFont
        }

        // Sync text from binding → view (avoid loop via guard)
        if !context.coordinator.isUpdating && textView.text != text {
            let selectedRange = textView.selectedRange
            textView.text = text
            textView.selectedRange = selectedRange
        }

        // Apply pending toolbar format action
        if let action = formatAction {
            DispatchQueue.main.async {
                formatAction = nil
                applyFormat(action, to: textView)
            }
        }

        // Handle focus request
        if requestFocus {
            DispatchQueue.main.async {
                requestFocus = false
                textView.becomeFirstResponder()
            }
        }
    }

    private func applyFormat(_ action: FormatAction, to textView: UITextView) {
        let wrapper = action.wrapper
        let range = textView.selectedRange
        let currentText = (textView.text as NSString)

        let selectedText = range.length > 0
            ? currentText.substring(with: range)
            : ""

        let replacement = "\(wrapper)\(selectedText)\(wrapper)"

        if let textRange = textView.selectedTextRange {
            textView.replace(textRange, withText: replacement)

            // Adjust cursor position
            if selectedText.isEmpty {
                let cursorPos = range.location + wrapper.utf16.count
                textView.selectedRange = NSRange(location: cursorPos, length: 0)
            } else {
                let selStart = range.location + wrapper.utf16.count
                textView.selectedRange = NSRange(location: selStart, length: selectedText.utf16.count)
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: MarkdownTextView
        weak var textView: UITextView?
        var isUpdating = false

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            isUpdating = true
            parent.text = textView.text
            isUpdating = false
        }
    }
}
#endif

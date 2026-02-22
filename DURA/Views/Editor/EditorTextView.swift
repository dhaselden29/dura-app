#if os(macOS)
import AppKit

/// NSTextView subclass that intercepts keyboard shortcuts for markdown formatting.
final class EditorTextView: NSTextView {
    /// Callback for highlight creation from context menu.
    var onHighlightRequest: ((NSRange, HighlightColor) -> Void)?
    /// Callback for annotation (comment) creation from context menu.
    var onAnnotationRequest: ((NSRange) -> Void)?

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
            for color in HighlightColor.userColors {
                let item = NSMenuItem(
                    title: color.displayName,
                    action: #selector(highlightWithColor(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = color
                item.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: color.displayName)
                item.image?.isTemplate = false
                let config = NSImage.SymbolConfiguration(paletteColors: [NSColor(color.swiftUIColor)])
                item.image = item.image?.withSymbolConfiguration(config)
                highlightMenu.addItem(item)
            }

            let highlightItem = NSMenuItem(title: "Highlight", action: nil, keyEquivalent: "")
            highlightItem.submenu = highlightMenu
            highlightItem.image = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "Highlight")
            menu.insertItem(highlightItem, at: 0)

            let commentItem = NSMenuItem(
                title: "Add Comment",
                action: #selector(addComment(_:)),
                keyEquivalent: ""
            )
            commentItem.target = self
            commentItem.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Add Comment")
            menu.insertItem(commentItem, at: 0)
        }

        return menu
    }

    @objc private func addComment(_ sender: NSMenuItem) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        onAnnotationRequest?(range)
    }

    @objc private func highlightWithColor(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? HighlightColor else { return }
        let range = selectedRange()
        guard range.length > 0 else { return }
        onHighlightRequest?(range, color)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags == .command, event.charactersIgnoringModifiers == "b" {
            wrapSelection(with: "**")
            return
        }

        if flags == .command, event.charactersIgnoringModifiers == "i" {
            wrapSelection(with: "_")
            return
        }

        if flags == .command, event.charactersIgnoringModifiers == "e" {
            wrapSelection(with: "`")
            return
        }

        if flags == [.command, .shift], event.charactersIgnoringModifiers == "x" {
            wrapSelection(with: "~~")
            return
        }

        if event.keyCode == 48 && flags.isEmpty {
            insertText("    ", replacementRange: selectedRange())
            return
        }

        if event.keyCode == 49 && flags.isEmpty && !isEditable {
            enclosingScrollView?.pageDown(nil)
            return
        }

        if event.keyCode == 49 && flags == .shift && !isEditable {
            enclosingScrollView?.pageUp(nil)
            return
        }

        super.keyDown(with: event)
    }

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
#endif

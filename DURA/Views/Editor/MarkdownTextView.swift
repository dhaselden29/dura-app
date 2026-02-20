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
    /// Called by the coordinator to apply a formatting action.
    func applyFormat(_ action: FormatAction) {
        wrapSelection(with: action.wrapper)
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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

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
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Allow the text view to expand horizontally within the scroll view
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

        scrollView.documentView = textView

        // Set initial text
        textView.string = text

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorTextView else { return }

        // Sync text from binding → view (avoid loop via guard)
        if !context.coordinator.isUpdating && textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        // Apply pending toolbar format action
        if let action = formatAction {
            DispatchQueue.main.async {
                formatAction = nil
                textView.applyFormat(action)
            }
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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)
        textView.textColor = UIColor.label
        textView.backgroundColor = .clear
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        textView.text = text
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
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

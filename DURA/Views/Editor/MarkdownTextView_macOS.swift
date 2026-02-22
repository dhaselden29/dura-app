#if os(macOS)
import SwiftUI
import AppKit

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
    var onScrollProgressChanged: ((Double) -> Void)?

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

        // Enable scroll observation for reading progress
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

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

        // Keep coordinator's parent reference current for callbacks
        context.coordinator.parent = self

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
        let currentLineSpacing = (textView.defaultParagraphStyle as? NSMutableParagraphStyle)?.lineSpacing
            ?? textView.defaultParagraphStyle?.lineSpacing
        let styleChanged = currentLineSpacing != newStyle.lineSpacing
        if textView.font?.fontName != expectedFont.fontName
            || textView.font?.pointSize != expectedFont.pointSize
            || styleChanged
        {
            let selectedRanges = textView.selectedRanges
            textView.font = expectedFont
            textView.defaultParagraphStyle = newStyle
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
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            if fullRange.length > 0 {
                textView.textStorage?.addAttribute(.font, value: expectedFont, range: fullRange)
                textView.textStorage?.addAttribute(.paragraphStyle, value: newStyle, range: fullRange)
                textView.textStorage?.addAttribute(.foregroundColor, value: theme.textColor, range: fullRange)
            }
            textView.selectedRanges = selectedRanges
            // New note loaded — reset scroll progress tracking
            context.coordinator.resetProgress()
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
        guard !highlights.isEmpty else { return }
        guard let textStorage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard fullRange.length > 0 else { return }

        textStorage.removeAttribute(.backgroundColor, range: fullRange)

        let bodyNS = textView.string as NSString
        for highlight in highlights {
            var range = NSRange(location: highlight.rangeStart, length: highlight.rangeLength)

            if range.location + range.length > bodyNS.length {
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

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: EditorTextView?
        var isUpdating = false
        private var highWaterMark: Double = 0
        private var debounceTimer: Timer?

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        deinit {
            debounceTimer?.invalidate()
            NotificationCenter.default.removeObserver(self)
        }

        func resetProgress() {
            highWaterMark = 0
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            parent.text = textView.string
            DispatchQueue.main.async { [weak self] in
                self?.isUpdating = false
            }
        }

        @objc func scrollViewBoundsDidChange(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView,
                  let textView = clipView.documentView as? NSTextView else { return }

            let documentHeight = textView.frame.height
            let visibleHeight = clipView.bounds.height
            let scrollableHeight = documentHeight - visibleHeight

            let percent: Double
            if scrollableHeight <= 0 {
                percent = 100.0
            } else {
                let scrollOffset = clipView.bounds.origin.y
                percent = min(100.0, max(0.0, scrollOffset / scrollableHeight * 100.0))
            }

            guard percent > highWaterMark else { return }
            highWaterMark = percent

            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.parent.onScrollProgressChanged?(self.highWaterMark)
            }
        }
    }
}
#endif

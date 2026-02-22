#if os(iOS)
import SwiftUI
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
    var onScrollProgressChanged: ((Double) -> Void)?

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
        // Keep coordinator's parent reference current for callbacks
        context.coordinator.parent = self

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
            // New note loaded — reset scroll progress tracking
            context.coordinator.resetProgress()
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

            if selectedText.isEmpty {
                let cursorPos = range.location + wrapper.utf16.count
                textView.selectedRange = NSRange(location: cursorPos, length: 0)
            } else {
                let selStart = range.location + wrapper.utf16.count
                textView.selectedRange = NSRange(location: selStart, length: selectedText.utf16.count)
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: UITextView?
        var isUpdating = false
        private var highWaterMark: Double = 0
        private var debounceTimer: Timer?

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        deinit {
            debounceTimer?.invalidate()
        }

        func resetProgress() {
            highWaterMark = 0
        }

        func textViewDidChange(_ textView: UITextView) {
            isUpdating = true
            parent.text = textView.text
            DispatchQueue.main.async { [weak self] in
                self?.isUpdating = false
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentHeight = scrollView.contentSize.height
            let visibleHeight = scrollView.bounds.height
            let scrollableHeight = contentHeight - visibleHeight

            let percent: Double
            if scrollableHeight <= 0 {
                percent = 100.0
            } else {
                let scrollOffset = scrollView.contentOffset.y
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

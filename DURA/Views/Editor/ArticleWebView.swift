#if os(macOS)
import SwiftUI
import WebKit

// MARK: - WKWebView Subclass with Custom Context Menu

final class ArticleWKWebView: WKWebView {
    var cachedSelectedText: String = ""
    var highlightHandler: ((String, HighlightColor) -> Void)?
    var annotationHandler: ((String) -> Void)?

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)

        guard !cachedSelectedText.isEmpty else { return }

        let separator = NSMenuItem.separator()
        menu.addItem(separator)

        // Add Comment
        let commentItem = NSMenuItem(
            title: "Add Comment",
            action: #selector(addCommentAction),
            keyEquivalent: ""
        )
        commentItem.target = self
        menu.addItem(commentItem)

        // Highlight submenu
        let highlightMenu = NSMenu()
        for color in HighlightColor.userColors {
            let item = NSMenuItem(
                title: color.displayName,
                action: #selector(highlightColorAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = color
            highlightMenu.addItem(item)
        }
        let highlightItem = NSMenuItem(title: "Highlight", action: nil, keyEquivalent: "")
        highlightItem.submenu = highlightMenu
        menu.addItem(highlightItem)
    }

    @objc private func addCommentAction() {
        guard !cachedSelectedText.isEmpty else { return }
        annotationHandler?(cachedSelectedText)
    }

    @objc private func highlightColorAction(_ sender: NSMenuItem) {
        guard !cachedSelectedText.isEmpty,
              let color = sender.representedObject as? HighlightColor else { return }
        highlightHandler?(cachedSelectedText, color)
    }
}

// MARK: - NSViewRepresentable

struct ArticleWebView: NSViewRepresentable {
    let markdown: String
    var highlights: [Highlight] = []
    var onHighlightCreated: ((Highlight) -> Void)?
    var onAnnotationRequest: ((String, Int, Int) -> Void)?
    var focusedHighlightID: UUID?
    var onScrollProgressChanged: ((Double) -> Void)?

    var fontSize: Double = ReaderDefaults.fontSize
    var lineSpacing: Double = ReaderDefaults.lineSpacing
    var fontFamily: ReaderFont = .system
    var maxWidth: Double = ReaderDefaults.maxWidth
    var theme: ReaderTheme = .light

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> ArticleWKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "scrollProgress")
        contentController.add(context.coordinator, name: "selectionChanged")
        config.userContentController = contentController

        let webView = ArticleWKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // Wire up context menu handlers
        webView.highlightHandler = { [weak webView] text, color in
            guard let webView else { return }
            let body = context.coordinator.parent.markdown as NSString
            let range = body.range(of: text)
            let highlight = Highlight(
                anchorText: text,
                rangeStart: range.location != NSNotFound ? range.location : 0,
                rangeLength: text.utf16.count,
                color: color
            )
            context.coordinator.parent.onHighlightCreated?(highlight)
        }

        webView.annotationHandler = { text in
            let body = context.coordinator.parent.markdown as NSString
            let range = body.range(of: text)
            context.coordinator.parent.onAnnotationRequest?(
                text,
                range.location != NSNotFound ? range.location : 0,
                text.utf16.count
            )
        }

        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif

        let html = ArticleHTMLRenderer.render(
            markdown: markdown,
            theme: theme,
            fontFamily: fontFamily,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            maxWidth: maxWidth,
            highlights: highlights
        )
        webView.loadHTMLString(html, baseURL: nil)

        context.coordinator.lastMarkdown = markdown
        context.coordinator.lastTheme = theme
        context.coordinator.lastFontFamily = fontFamily
        context.coordinator.lastFontSize = fontSize
        context.coordinator.lastLineSpacing = lineSpacing
        context.coordinator.lastMaxWidth = maxWidth
        context.coordinator.lastHighlightCount = highlights.count

        return webView
    }

    func updateNSView(_ webView: ArticleWKWebView, context: Context) {
        context.coordinator.parent = self

        // Re-wire handlers to capture current parent
        webView.highlightHandler = { [weak webView] text, color in
            guard let _ = webView else { return }
            let body = context.coordinator.parent.markdown as NSString
            let range = body.range(of: text)
            let highlight = Highlight(
                anchorText: text,
                rangeStart: range.location != NSNotFound ? range.location : 0,
                rangeLength: text.utf16.count,
                color: color
            )
            context.coordinator.parent.onHighlightCreated?(highlight)
        }

        webView.annotationHandler = { text in
            let body = context.coordinator.parent.markdown as NSString
            let range = body.range(of: text)
            context.coordinator.parent.onAnnotationRequest?(
                text,
                range.location != NSNotFound ? range.location : 0,
                text.utf16.count
            )
        }

        let coord = context.coordinator

        // Full reload if markdown changed
        if markdown != coord.lastMarkdown {
            coord.pageLoaded = false
            let html = ArticleHTMLRenderer.render(
                markdown: markdown,
                theme: theme,
                fontFamily: fontFamily,
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                maxWidth: maxWidth,
                highlights: highlights
            )
            webView.loadHTMLString(html, baseURL: nil)
            coord.lastMarkdown = markdown
            coord.lastTheme = theme
            coord.lastFontFamily = fontFamily
            coord.lastFontSize = fontSize
            coord.lastLineSpacing = lineSpacing
            coord.lastMaxWidth = maxWidth
            coord.lastHighlightCount = highlights.count
            return
        }

        // Dynamic theme update
        if theme != coord.lastTheme {
            coord.lastTheme = theme
            let linkColor = theme == .dark ? "#6BB5FF" : "#0366D6"
            let codeBg = theme == .dark ? "#2D2D2D" : "#F6F8FA"
            let borderColor = theme == .dark ? "#555" : "#DDD"
            let js = "updateTheme('\(theme.cssBackground)','\(theme.cssTextColor)','\(linkColor)','\(codeBg)','\(borderColor)');"
            webView.evaluateJavaScript(js)
        }

        // Dynamic font update
        if fontFamily != coord.lastFontFamily {
            coord.lastFontFamily = fontFamily
            let escapedFont = fontFamily.cssValue.replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("updateFont('\(escapedFont)');")
        }

        // Dynamic font size update
        if fontSize != coord.lastFontSize {
            coord.lastFontSize = fontSize
            webView.evaluateJavaScript("updateFontSize(\(Int(fontSize)));")
        }

        // Dynamic line spacing update
        if lineSpacing != coord.lastLineSpacing {
            coord.lastLineSpacing = lineSpacing
            let value = String(format: "%.1f", 1.4 + lineSpacing * 0.04)
            webView.evaluateJavaScript("updateLineSpacing('\(value)');")
        }

        // Dynamic max width update
        if maxWidth != coord.lastMaxWidth {
            coord.lastMaxWidth = maxWidth
            let value = maxWidth < 10000 ? "\(Int(maxWidth))px" : "100%"
            webView.evaluateJavaScript("updateMaxWidth('\(value)');")
        }

        // Highlights changed — re-apply
        if highlights.count != coord.lastHighlightCount {
            coord.lastHighlightCount = highlights.count
            let json = highlights.map { h in
                let escapedText = h.anchorText
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "'", with: "\\'")
                return "{\"id\":\"\(h.id.uuidString)\",\"anchorText\":\"\(escapedText)\",\"color\":\"\(h.color.rawValue)\",\"cssColor\":\"\(h.color.cssColor)\"}"
            }
            let arrayStr = "[\(json.joined(separator: ","))]"
            webView.evaluateJavaScript("applyHighlights(\(arrayStr));")
        }

        // Scroll to focused highlight
        if let focusedID = focusedHighlightID, focusedID != coord.lastFocusedHighlightID {
            coord.lastFocusedHighlightID = focusedID
            webView.evaluateJavaScript("scrollToHighlight('\(focusedID.uuidString)');")
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: ArticleWebView
        weak var webView: ArticleWKWebView?
        var pageLoaded = false
        var highWaterMark: Double = 0

        // State tracking for updateNSView diffing
        var lastMarkdown: String = ""
        var lastTheme: ReaderTheme = .light
        var lastFontFamily: ReaderFont = .system
        var lastFontSize: Double = 0
        var lastLineSpacing: Double = 0
        var lastMaxWidth: Double = 0
        var lastHighlightCount: Int = 0
        var lastFocusedHighlightID: UUID?

        init(_ parent: ArticleWebView) {
            self.parent = parent
        }

        // MARK: WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "scrollProgress":
                if let percent = message.body as? Double {
                    guard percent > highWaterMark else { return }
                    highWaterMark = percent
                    parent.onScrollProgressChanged?(percent)
                }
            case "selectionChanged":
                if let text = message.body as? String {
                    webView?.cachedSelectedText = text
                }
            default:
                break
            }
        }

        // MARK: WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageLoaded = true

            // Scroll to focused highlight if set before page loaded
            if let focusedID = parent.focusedHighlightID {
                lastFocusedHighlightID = focusedID
                webView.evaluateJavaScript("scrollToHighlight('\(focusedID.uuidString)');")
            }
        }
    }
}
#endif

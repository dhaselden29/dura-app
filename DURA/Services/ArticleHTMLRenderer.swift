import Foundation

/// Generates a full HTML document from markdown + reader preferences + highlights
/// for rendering in the WKWebView-based article reader.
enum ArticleHTMLRenderer {

    /// Renders a complete HTML document ready for WKWebView.
    static func render(
        markdown: String,
        theme: ReaderTheme = .light,
        fontFamily: ReaderFont = .system,
        fontSize: Double = ReaderDefaults.fontSize,
        lineSpacing: Double = ReaderDefaults.lineSpacing,
        maxWidth: Double = ReaderDefaults.maxWidth,
        highlights: [Highlight] = []
    ) -> String {
        let bodyHTML = HTMLExportProvider.renderHTML(from: markdown)
        let highlightsJSON = Self.highlightsJSON(highlights)

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        :root {
            --bg-color: \(theme.cssBackground);
            --text-color: \(theme.cssTextColor);
            --font-family: \(fontFamily.cssValue);
            --font-size: \(Int(fontSize))px;
            --line-spacing: \(String(format: "%.1f", 1.4 + lineSpacing * 0.04));
            --max-width: \(maxWidth < 10000 ? "\(Int(maxWidth))px" : "100%");
        }

        * { box-sizing: border-box; }

        body {
            font-family: var(--font-family);
            font-size: var(--font-size);
            line-height: var(--line-spacing);
            color: var(--text-color);
            background: var(--bg-color);
            max-width: var(--max-width);
            margin: 0 auto;
            padding: 1.5rem 2rem 4rem;
            -webkit-font-smoothing: antialiased;
        }

        h1, h2, h3, h4, h5, h6 {
            margin-top: 1.5em;
            margin-bottom: 0.5em;
            line-height: 1.3;
        }
        h1 { font-size: 1.8em; }
        h2 { font-size: 1.4em; }
        h3 { font-size: 1.2em; }

        p { margin: 0.8em 0; }

        img {
            max-width: 100%;
            height: auto;
            border-radius: 6px;
            display: block;
            margin: 1em auto;
        }

        figure {
            margin: 1.5em 0;
            text-align: center;
        }
        figcaption {
            font-size: 0.85em;
            color: var(--text-color);
            opacity: 0.6;
            margin-top: 0.5em;
        }

        pre {
            background: \(theme == .dark ? "#2D2D2D" : "#F6F8FA");
            border-radius: 8px;
            padding: 1em;
            overflow-x: auto;
            font-size: 0.9em;
        }
        code {
            font-family: 'SF Mono', Menlo, Consolas, monospace;
            font-size: 0.9em;
        }
        :not(pre) > code {
            background: \(theme == .dark ? "#2D2D2D" : "#F0F0F0");
            padding: 0.15em 0.4em;
            border-radius: 4px;
        }

        blockquote {
            border-left: 4px solid \(theme == .dark ? "#555" : "#DDD");
            margin: 1em 0;
            padding: 0.5em 1em;
            color: var(--text-color);
            opacity: 0.8;
        }

        a { color: \(theme == .dark ? "#6BB5FF" : "#0366D6"); text-decoration: none; }
        a:hover { text-decoration: underline; }

        hr {
            border: none;
            border-top: 1px solid \(theme == .dark ? "#444" : "#EEE");
            margin: 2em 0;
        }

        details { margin: 1em 0; }
        summary { cursor: pointer; font-weight: 600; }

        ul, ol { padding-left: 1.5em; }
        li { margin: 0.3em 0; }

        /* Highlight marks */
        mark[data-color] {
            border-radius: 2px;
            padding: 0.1em 0;
        }

        /* Flash animation for scroll-to-highlight */
        @keyframes highlightFlash {
            0% { outline: 3px solid rgba(255, 149, 0, 0.8); outline-offset: 2px; }
            100% { outline: 3px solid rgba(255, 149, 0, 0); outline-offset: 2px; }
        }
        mark.flash {
            animation: highlightFlash 1.5s ease-out;
        }

        ::selection {
            background: rgba(0, 120, 255, 0.3);
        }
        </style>
        </head>
        <body>
        \(bodyHTML)

        <script>
        // --- Highlight Data ---
        var highlightData = \(highlightsJSON);

        // --- Apply Highlights ---
        function applyHighlights(data) {
            clearHighlights();
            for (var i = 0; i < data.length; i++) {
                applyHighlight(data[i]);
            }
        }

        function applyHighlight(h) {
            var walker = document.createTreeWalker(
                document.body, NodeFilter.SHOW_TEXT, null, false
            );
            var searchText = h.anchorText;
            var node;
            while (node = walker.nextNode()) {
                var idx = node.textContent.indexOf(searchText);
                if (idx >= 0) {
                    var range = document.createRange();
                    range.setStart(node, idx);
                    range.setEnd(node, idx + searchText.length);
                    var mark = document.createElement('mark');
                    mark.setAttribute('data-color', h.color);
                    mark.setAttribute('data-id', h.id);
                    mark.style.background = h.cssColor;
                    range.surroundContents(mark);
                    break;
                }
            }
        }

        function clearHighlights() {
            var marks = document.querySelectorAll('mark[data-id]');
            for (var i = 0; i < marks.length; i++) {
                var parent = marks[i].parentNode;
                while (marks[i].firstChild) {
                    parent.insertBefore(marks[i].firstChild, marks[i]);
                }
                parent.removeChild(marks[i]);
                parent.normalize();
            }
        }

        // --- Scroll Progress ---
        var scrollThrottleTimer = null;
        window.addEventListener('scroll', function() {
            if (scrollThrottleTimer) return;
            scrollThrottleTimer = setTimeout(function() {
                scrollThrottleTimer = null;
                var scrollTop = window.scrollY || document.documentElement.scrollTop;
                var docHeight = document.documentElement.scrollHeight - window.innerHeight;
                if (docHeight <= 0) return;
                var percent = Math.min(100, Math.max(0, (scrollTop / docHeight) * 100));
                window.webkit.messageHandlers.scrollProgress.postMessage(percent);
            }, 300);
        });

        // --- Selection Tracking ---
        document.addEventListener('selectionchange', function() {
            var sel = window.getSelection();
            var text = sel ? sel.toString() : '';
            window.webkit.messageHandlers.selectionChanged.postMessage(text);
        });

        // --- Scroll to Highlight ---
        function scrollToHighlight(id) {
            var mark = document.querySelector('mark[data-id="' + id + '"]');
            if (mark) {
                mark.scrollIntoView({ behavior: 'smooth', block: 'center' });
                mark.classList.add('flash');
                setTimeout(function() { mark.classList.remove('flash'); }, 1500);
            }
        }

        // --- Dynamic Preference Updates ---
        function updateTheme(bg, textColor, linkColor, codeBg, borderColor) {
            document.documentElement.style.setProperty('--bg-color', bg);
            document.documentElement.style.setProperty('--text-color', textColor);
            var links = document.querySelectorAll('a');
            for (var i = 0; i < links.length; i++) { links[i].style.color = linkColor; }
            var pres = document.querySelectorAll('pre');
            for (var i = 0; i < pres.length; i++) { pres[i].style.background = codeBg; }
            var codes = document.querySelectorAll(':not(pre) > code');
            for (var i = 0; i < codes.length; i++) { codes[i].style.background = codeBg; }
            var bqs = document.querySelectorAll('blockquote');
            for (var i = 0; i < bqs.length; i++) { bqs[i].style.borderLeftColor = borderColor; }
            var hrs = document.querySelectorAll('hr');
            for (var i = 0; i < hrs.length; i++) { hrs[i].style.borderTopColor = borderColor; }
        }

        function updateFont(family) {
            document.documentElement.style.setProperty('--font-family', family);
        }

        function updateFontSize(size) {
            document.documentElement.style.setProperty('--font-size', size + 'px');
        }

        function updateLineSpacing(value) {
            document.documentElement.style.setProperty('--line-spacing', value);
        }

        function updateMaxWidth(value) {
            document.documentElement.style.setProperty('--max-width', value);
        }

        // Apply highlights on load
        applyHighlights(highlightData);
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Helpers

    private static func highlightsJSON(_ highlights: [Highlight]) -> String {
        guard !highlights.isEmpty else { return "[]" }
        let entries = highlights.map { h in
            let escapedText = h.anchorText
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            return """
            {"id":"\(h.id.uuidString)","anchorText":"\(escapedText)","color":"\(h.color.rawValue)","cssColor":"\(h.color.cssColor)"}
            """
        }
        return "[\(entries.joined(separator: ","))]"
    }
}

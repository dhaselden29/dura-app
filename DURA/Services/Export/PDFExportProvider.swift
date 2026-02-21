import Foundation
import WebKit

struct PDFExportProvider: ExportProvider {
    static let format = ExportFormat.pdf

    func export(title: String, markdown: String, progress: @Sendable (Double) -> Void) async throws -> ExportResult {
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExportError.emptyContent
        }

        progress(0.1)

        let html = HTMLExportProvider.wrapInDocument(
            title: title,
            body: HTMLExportProvider.renderHTML(from: markdown)
        )

        progress(0.4)

        let pdfData = try await generatePDF(from: html)

        progress(0.9)

        let filename = sanitizeFilename(title) + ".pdf"

        progress(1.0)

        return ExportResult(
            data: pdfData,
            filename: filename,
            utType: ExportFormat.pdf.utType,
            mimeType: ExportFormat.pdf.mimeType
        )
    }

    // MARK: - PDF Generation

    @MainActor
    private func generatePDF(from html: String) async throws -> Data {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 612, height: 792))
        webView.navigationDelegate = nil

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PDFNavigationDelegate { result in
                continuation.resume(with: result)
            }
            // Prevent delegate from being deallocated before callback fires
            objc_setAssociatedObject(webView, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            webView.navigationDelegate = delegate
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}

// MARK: - Navigation Delegate

private final class PDFNavigationDelegate: NSObject, WKNavigationDelegate {
    private let completion: @MainActor (Result<Data, Error>) -> Void

    init(completion: @escaping @MainActor (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            do {
                let config = WKPDFConfiguration()
                // US Letter with 50pt margins (matching previous layout)
                let margin: CGFloat = 50
                config.rect = CGRect(x: margin, y: margin,
                                     width: 612 - 2 * margin,
                                     height: 792 - 2 * margin)
                let data = try await webView.pdf(configuration: config)
                completion(.success(data))
            } catch {
                completion(.failure(ExportError.pdfGenerationFailed(error.localizedDescription)))
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            completion(.failure(ExportError.pdfGenerationFailed(error.localizedDescription)))
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            completion(.failure(ExportError.pdfGenerationFailed(error.localizedDescription)))
        }
    }
}

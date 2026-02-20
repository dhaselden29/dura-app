import Foundation

struct MarkdownExportProvider: ExportProvider {
    static let format = ExportFormat.markdown

    func export(title: String, markdown: String, progress: @Sendable (Double) -> Void) async throws -> ExportResult {
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExportError.emptyContent
        }

        progress(0.3)

        var output = markdown

        // Prepend title as H1 if body doesn't already start with one
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.hasPrefix("# ") {
            output = "# \(title)\n\n\(markdown)"
        }

        progress(0.8)

        guard let data = output.data(using: .utf8) else {
            throw ExportError.renderFailed("UTF-8 encoding failed")
        }

        let filename = sanitizeFilename(title) + ".md"

        progress(1.0)

        return ExportResult(
            data: data,
            filename: filename,
            utType: ExportFormat.markdown.utType,
            mimeType: ExportFormat.markdown.mimeType
        )
    }
}

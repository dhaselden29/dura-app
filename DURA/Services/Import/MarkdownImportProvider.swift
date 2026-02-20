import Foundation
import UniformTypeIdentifiers

struct MarkdownImportProvider: ImportProvider {
    static let supportedTypes: [UTType] = [.markdown]

    func process(data: Data, filename: String, progress: @Sendable (Double) -> Void) async throws -> ImportResult {
        guard !data.isEmpty else { throw ImportError.emptyFile }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ImportError.encodingFailed
        }

        progress(0.5)

        let title = extractTitle(from: text) ?? filenameStem(filename)
        let body = text

        progress(1.0)

        return ImportResult(
            title: title,
            body: body,
            source: .markdown,
            originalFilename: filename,
            originalData: data,
            mimeType: "text/markdown"
        )
    }

    private func extractTitle(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                let title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    return title
                }
            }
        }
        return nil
    }
}

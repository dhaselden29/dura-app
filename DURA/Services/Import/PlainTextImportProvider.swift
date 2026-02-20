import Foundation
import UniformTypeIdentifiers

struct PlainTextImportProvider: ImportProvider {
    static let supportedTypes: [UTType] = [.plainText]

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
            source: .plainText,
            originalFilename: filename,
            originalData: data,
            mimeType: "text/plain"
        )
    }

    private func extractTitle(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if trimmed.count > 100 {
                    return String(trimmed.prefix(100))
                }
                return trimmed
            }
        }
        return nil
    }
}

import Foundation
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct RTFImportProvider: ImportProvider {
    static let supportedTypes: [UTType] = [.rtf, .rtfd]

    func process(data: Data, filename: String, progress: @Sendable (Double) -> Void) async throws -> ImportResult {
        guard !data.isEmpty else { throw ImportError.emptyFile }

        progress(0.3)

        let attributedString: NSAttributedString
        do {
            attributedString = try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        } catch {
            throw ImportError.parseFailed("RTF parsing failed: \(error.localizedDescription)")
        }

        let text = attributedString.string
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.emptyFile
        }

        progress(0.7)

        let title = extractTitle(from: text) ?? filenameStem(filename)

        progress(1.0)

        return ImportResult(
            title: title,
            body: text,
            source: .rtf,
            originalFilename: filename,
            originalData: data,
            mimeType: "application/rtf"
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

import Foundation
import UniformTypeIdentifiers

// MARK: - Export Format

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case markdown
    case html
    case pdf

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .markdown: "Markdown"
        case .html: "HTML"
        case .pdf: "PDF"
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .html: "html"
        case .pdf: "pdf"
        }
    }

    var utType: UTType {
        switch self {
        case .markdown: .markdown
        case .html: .html
        case .pdf: .pdf
        }
    }

    var mimeType: String {
        switch self {
        case .markdown: "text/markdown"
        case .html: "text/html"
        case .pdf: "application/pdf"
        }
    }
}

// MARK: - Export Result

struct ExportResult: Sendable {
    let data: Data
    let filename: String
    let utType: UTType
    let mimeType: String
}

// MARK: - Export Error

enum ExportError: LocalizedError, Sendable {
    case emptyContent
    case renderFailed(String)
    case pdfGenerationFailed(String)
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            "The note has no content to export."
        case .renderFailed(let reason):
            "Failed to render content: \(reason)"
        case .pdfGenerationFailed(let reason):
            "Failed to generate PDF: \(reason)"
        case .unsupportedFormat(let format):
            "Unsupported export format: \(format)"
        }
    }
}

// MARK: - Export Provider Protocol

protocol ExportProvider: Sendable {
    static var format: ExportFormat { get }
    func export(title: String, markdown: String, progress: @Sendable (Double) -> Void) async throws -> ExportResult
}

// MARK: - Helpers

func sanitizeFilename(_ name: String) -> String {
    let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
    let sanitized = name.unicodeScalars.filter { !invalidChars.contains($0) }
    let result = String(String.UnicodeScalarView(sanitized))
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return result.isEmpty ? "Untitled" : result
}

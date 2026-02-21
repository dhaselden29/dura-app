import Foundation
import UniformTypeIdentifiers

// MARK: - Import Result

struct ImportResult: Sendable {
    let title: String
    let body: String
    let source: ImportSource
    let originalFilename: String
    let originalData: Data
    let mimeType: String
    var ocrText: String?

    // Metadata from YAML front matter (web clips)
    var sourceURL: String?
    var excerpt: String?
    var tagNames: [String]?
    var notebookName: String?
    var featuredImageURL: String?
}

// MARK: - Import Error

enum ImportError: LocalizedError, Sendable {
    case unsupportedType(String)
    case encodingFailed
    case parseFailed(String)
    case emptyFile
    case fileReadFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedType(let type):
            "Unsupported file type: \(type)"
        case .encodingFailed:
            "Could not decode the file's text encoding."
        case .parseFailed(let reason):
            "Failed to parse file: \(reason)"
        case .emptyFile:
            "The file is empty."
        case .fileReadFailed(let reason):
            "Failed to read file: \(reason)"
        }
    }
}

// MARK: - Import Provider Protocol

protocol ImportProvider: Sendable {
    static var supportedTypes: [UTType] { get }
    func process(data: Data, filename: String, progress: @Sendable (Double) -> Void) async throws -> ImportResult
}

// MARK: - UTType Extensions

extension UTType {
    static let markdown = UTType("net.daringfireball.markdown")!
}

// MARK: - Helpers

func filenameStem(_ filename: String) -> String {
    let name = (filename as NSString).lastPathComponent
    let ext = (name as NSString).pathExtension
    if ext.isEmpty {
        return name
    }
    return String(name.dropLast(ext.count + 1))
}

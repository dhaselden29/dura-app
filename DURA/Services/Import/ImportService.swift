import Foundation
import UniformTypeIdentifiers

@MainActor
final class ImportService {
    private let dataService: DataService
    private let providers: [UTType: any ImportProvider]

    /// Content types accepted by `.fileImporter()`.
    let supportedContentTypes: [UTType]

    init(dataService: DataService) {
        self.dataService = dataService

        let allProviders: [any ImportProvider] = [
            MarkdownImportProvider(),
            PlainTextImportProvider(),
            RTFImportProvider(),
            PDFImportProvider(),
            DocxImportProvider(),
            ImageImportProvider(),
        ]

        var lookup: [UTType: any ImportProvider] = [:]
        for provider in allProviders {
            for type in type(of: provider).supportedTypes {
                lookup[type] = provider
            }
        }
        self.providers = lookup
        self.supportedContentTypes = Array(lookup.keys)
    }

    // MARK: - Import

    func importFile(
        at url: URL,
        into notebook: Notebook? = nil,
        progress: @escaping @MainActor @Sendable (Double) -> Void = { _ in }
    ) async throws -> Note {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.fileReadFailed(error.localizedDescription)
        }

        let filename = url.lastPathComponent
        let provider = try resolveProvider(for: url)

        let result = try await { [provider] in
            try await provider.process(data: data, filename: filename) { value in
                Task { @MainActor in
                    progress(value)
                }
            }
        }()

        // Resolve notebook: front matter notebook overrides only when no explicit `into` parameter
        var targetNotebook = notebook
        if targetNotebook == nil, let notebookName = result.notebookName, !notebookName.isEmpty {
            targetNotebook = try findOrCreateNotebook(name: notebookName)
        }

        // Create note
        let note = dataService.createNote(
            title: result.title,
            body: result.body,
            source: result.source,
            notebook: targetNotebook
        )
        note.originalFormat = result.mimeType
        note.sourceURL = result.sourceURL ?? url.absoluteString

        // Apply front matter metadata
        if let tagNames = result.tagNames, !tagNames.isEmpty {
            for tagName in tagNames {
                let tag = try dataService.findOrCreateTag(name: tagName)
                dataService.addTag(tag, to: note)
            }
        }

        // Create attachment with original file data
        let attachment = dataService.createAttachment(
            filename: result.originalFilename,
            data: result.originalData,
            mimeType: result.mimeType,
            note: note
        )
        attachment.ocrText = result.ocrText

        try dataService.save()

        return note
    }

    // MARK: - Notebook Resolution

    private func findOrCreateNotebook(name: String) throws -> Notebook {
        let notebooks = try dataService.fetchNotebooks()
        if let existing = notebooks.first(where: { $0.name == name }) {
            return existing
        }
        return dataService.createNotebook(name: name)
    }

    // MARK: - Provider Resolution

    private func resolveProvider(for url: URL) throws -> any ImportProvider {
        let ext = url.pathExtension.lowercased()

        // Try exact UTType match from extension
        if let uttype = UTType(filenameExtension: ext) {
            if let provider = providers[uttype] {
                return provider
            }

            // Conformance fallback — e.g. a .text file conforms to .plainText
            for (type, provider) in providers {
                if uttype.conforms(to: type) {
                    return provider
                }
            }
        }

        throw ImportError.unsupportedType(ext.isEmpty ? "unknown" : ext)
    }
}

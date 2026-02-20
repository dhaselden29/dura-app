import Foundation

final class ExportService: Sendable {
    private let providers: [ExportFormat: any ExportProvider]

    init() {
        let allProviders: [any ExportProvider] = [
            MarkdownExportProvider(),
            HTMLExportProvider(),
            PDFExportProvider(),
        ]

        var lookup: [ExportFormat: any ExportProvider] = [:]
        for provider in allProviders {
            lookup[type(of: provider).format] = provider
        }
        self.providers = lookup
    }

    var supportedFormats: [ExportFormat] {
        ExportFormat.allCases
    }

    func export(
        title: String,
        markdown: String,
        format: ExportFormat,
        progress: @Sendable @escaping (Double) -> Void = { _ in }
    ) async throws -> ExportResult {
        guard let provider = providers[format] else {
            throw ExportError.unsupportedFormat(format.displayName)
        }

        return try await provider.export(title: title, markdown: markdown, progress: progress)
    }
}

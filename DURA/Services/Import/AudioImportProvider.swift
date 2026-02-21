import Foundation
import UniformTypeIdentifiers

struct AudioImportProvider: ImportProvider {
    static let supportedTypes: [UTType] = [
        .mp3,
        .mpeg4Audio,
        .wav,
        UTType("public.aiff-audio")!,
        UTType("public.aac-audio")!,
    ]

    func process(data: Data, filename: String, progress: @Sendable (Double) -> Void) async throws -> ImportResult {
        guard !data.isEmpty else { throw ImportError.emptyFile }

        progress(0.5)

        let body = "🔊 [\(filename)](attachment://\(filename))"

        progress(1.0)

        return ImportResult(
            title: filenameStem(filename),
            body: body,
            source: .audio,
            originalFilename: filename,
            originalData: data,
            mimeType: mimeType(for: filename)
        )
    }

    private func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        case "aiff", "aif": return "audio/aiff"
        case "aac": return "audio/aac"
        default: return "audio/mpeg"
        }
    }
}

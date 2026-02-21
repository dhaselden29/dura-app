import Foundation
import LinkPresentation

/// Fetches page metadata (title, thumbnail) using Apple's LinkPresentation framework.
struct LinkMetadataFetcher: Sendable {
    /// Fetches metadata for the given URL, returning an optional title and JPEG thumbnail data.
    func fetchMetadata(for url: URL) async -> (title: String?, imageData: Data?) {
        let provider = LPMetadataProvider()
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            let title = metadata.title
            let imageData = await loadImageData(from: metadata.imageProvider)
            return (title, imageData)
        } catch {
            return (nil, nil)
        }
    }

    private func loadImageData(from provider: NSItemProvider?) async -> Data? {
        guard let provider else { return nil }

        #if canImport(AppKit)
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: NSImage.self) { object, _ in
                guard let image = object as? NSImage,
                      let tiff = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff) else {
                    continuation.resume(returning: nil)
                    return
                }
                let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
                continuation.resume(returning: jpeg)
            }
        }
        #else
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else {
                    continuation.resume(returning: nil)
                    return
                }
                let jpeg = image.jpegData(compressionQuality: 0.7)
                continuation.resume(returning: jpeg)
            }
        }
        #endif
    }
}

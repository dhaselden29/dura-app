import Foundation
import UniformTypeIdentifiers
import Vision
import ImageIO

struct ImageImportProvider: ImportProvider {
    static let supportedTypes: [UTType] = [.png, .jpeg, .heic, .tiff, .bmp, .gif]

    func process(data: Data, filename: String, progress: @Sendable (Double) -> Void) async throws -> ImportResult {
        guard !data.isEmpty else { throw ImportError.emptyFile }

        progress(0.3)

        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ImportError.parseFailed("Could not load image.")
        }

        let ocrText = try await recognizeText(in: cgImage)

        guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // No text found — still create a note with the image as attachment
            progress(1.0)
            return ImportResult(
                title: filenameStem(filename),
                body: "",
                source: .image,
                originalFilename: filename,
                originalData: data,
                mimeType: mimeType(for: filename)
            )
        }

        progress(1.0)

        let title = extractTitle(from: ocrText) ?? filenameStem(filename)

        var result = ImportResult(
            title: title,
            body: ocrText,
            source: .image,
            originalFilename: filename,
            originalData: data,
            mimeType: mimeType(for: filename)
        )
        result.ocrText = ocrText

        return result
    }

    // MARK: - OCR

    private func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: ImportError.parseFailed("OCR failed: \(error.localizedDescription)"))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ImportError.parseFailed("OCR failed: \(error.localizedDescription)"))
            }
        }
    }

    // MARK: - Helpers

    private func extractTitle(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed.count > 100 ? String(trimmed.prefix(100)) : trimmed
            }
        }
        return nil
    }

    private func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "tiff", "tif": return "image/tiff"
        case "bmp": return "image/bmp"
        case "gif": return "image/gif"
        default: return "image/png"
        }
    }
}

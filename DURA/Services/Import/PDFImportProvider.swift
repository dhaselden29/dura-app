import Foundation
import PDFKit
import UniformTypeIdentifiers
import Vision
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct PDFImportProvider: ImportProvider {
    static let supportedTypes: [UTType] = [.pdf]

    /// Minimum character count to consider a page as having a usable text layer.
    private static let textLayerThreshold = 20

    func process(data: Data, filename: String, progress: @Sendable (Double) -> Void) async throws -> ImportResult {
        guard !data.isEmpty else { throw ImportError.emptyFile }

        guard let document = PDFDocument(data: data) else {
            throw ImportError.parseFailed("Could not open PDF document.")
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else { throw ImportError.emptyFile }

        var pages: [String] = []
        var didOCR = false

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }

            let pageText: String
            let existingText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if existingText.count >= Self.textLayerThreshold {
                pageText = existingText
            } else {
                // OCR this page
                pageText = try await ocrPage(page)
                if !pageText.isEmpty {
                    didOCR = true
                }
            }

            if !pageText.isEmpty {
                if pageCount > 1 {
                    pages.append("## Page \(i + 1)\n\n\(pageText)")
                } else {
                    pages.append(pageText)
                }
            }

            progress(Double(i + 1) / Double(pageCount))
        }

        let body = pages.joined(separator: "\n\n")
        let title = extractTitle(from: body) ?? filenameStem(filename)

        var result = ImportResult(
            title: title,
            body: body,
            source: .pdf,
            originalFilename: filename,
            originalData: data,
            mimeType: "application/pdf"
        )

        if didOCR {
            result.ocrText = body
        }

        return result
    }

    // MARK: - OCR

    private func ocrPage(_ page: PDFPage) async throws -> String {
        guard let image = renderPageToImage(page) else {
            return ""
        }

        return try await withCheckedThrowingContinuation { continuation in
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

    // MARK: - Page Rendering

    private func renderPageToImage(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }
        context.setFillColor(.white)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let uiImage = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        return uiImage.cgImage
        #endif
    }

    // MARK: - Helpers

    private func extractTitle(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip page headers
            if trimmed.hasPrefix("## Page ") { continue }
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

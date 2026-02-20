import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct PDFExportProvider: ExportProvider {
    static let format = ExportFormat.pdf

    func export(title: String, markdown: String, progress: @Sendable (Double) -> Void) async throws -> ExportResult {
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExportError.emptyContent
        }

        progress(0.1)

        let html = HTMLExportProvider.wrapInDocument(
            title: title,
            body: HTMLExportProvider.renderHTML(from: markdown)
        )

        progress(0.4)

        let pdfData = try generatePDF(from: html)

        progress(0.9)

        let filename = sanitizeFilename(title) + ".pdf"

        progress(1.0)

        return ExportResult(
            data: pdfData,
            filename: filename,
            utType: ExportFormat.pdf.utType,
            mimeType: ExportFormat.pdf.mimeType
        )
    }

    // MARK: - PDF Generation

    private func generatePDF(from html: String) throws -> Data {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return try generatePDFMacOS(from: html)
        #elseif canImport(UIKit)
        return try generatePDFiOS(from: html)
        #else
        throw ExportError.pdfGenerationFailed("PDF generation not available on this platform")
        #endif
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func generatePDFMacOS(from html: String) throws -> Data {
        guard let htmlData = html.data(using: .utf8) else {
            throw ExportError.pdfGenerationFailed("Could not encode HTML")
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        let attrString: NSAttributedString
        do {
            attrString = try NSAttributedString(data: htmlData, options: options, documentAttributes: nil)
        } catch {
            throw ExportError.pdfGenerationFailed("HTML parsing failed: \(error.localizedDescription)")
        }

        // Page dimensions: US Letter with 50pt margins
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentRect = CGRect(
            x: margin, y: margin,
            width: pageWidth - 2 * margin,
            height: pageHeight - 2 * margin
        )

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.pdfGenerationFailed("Could not create PDF context")
        }

        // Use CTFramesetter for reliable multi-page PDF rendering
        let framesetter = CTFramesetterCreateWithAttributedString(attrString)
        let totalLength = attrString.length
        var currentIndex = 0

        while currentIndex < totalLength {
            context.beginPage(mediaBox: &mediaBox)

            let path = CGPath(rect: contentRect, transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: currentIndex, length: 0),
                path,
                nil
            )

            // Core Text draws in a flipped coordinate system relative to PDF
            context.saveGState()
            context.translateBy(x: 0, y: pageHeight)
            context.scaleBy(x: 1.0, y: -1.0)
            CTFrameDraw(frame, context)
            context.restoreGState()

            // Advance past the characters that fit on this page
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            if visibleRange.length == 0 { break }
            currentIndex += visibleRange.length

            context.endPage()
        }

        context.closePDF()

        return pdfData as Data
    }
    #endif

    #if canImport(UIKit)
    private func generatePDFiOS(from html: String) throws -> Data {
        guard let htmlData = html.data(using: .utf8) else {
            throw ExportError.pdfGenerationFailed("Could not encode HTML")
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        let attrString: NSAttributedString
        do {
            attrString = try NSAttributedString(data: htmlData, options: options, documentAttributes: nil)
        } catch {
            throw ExportError.pdfGenerationFailed("HTML parsing failed: \(error.localizedDescription)")
        }

        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let printableRect = CGRect(x: margin, y: margin, width: pageWidth - 2 * margin, height: pageHeight - 2 * margin)
        let paperRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        formatter.perPageContentInsets = UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)

        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)

        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }

        UIGraphicsEndPDFContext()

        return pdfData as Data
    }
    #endif
}

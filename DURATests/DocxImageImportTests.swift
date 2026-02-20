import Testing
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
@testable import DURA

// MARK: - Image Import Provider Tests

@Suite("ImageImportProvider")
struct ImageImportProviderTests {

    @Test("Supports expected image types")
    func supportedTypes() {
        let types = ImageImportProvider.supportedTypes
        #expect(types.contains(.png))
        #expect(types.contains(.jpeg))
        #expect(types.contains(.heic))
        #expect(types.contains(.tiff))
    }

    @Test("OCR extracts text from image with rendered text")
    func ocrExtractsText() async throws {
        guard let imageData = createImageWithText("Hello World from OCR test") else {
            Issue.record("Could not create test image")
            return
        }

        let provider = ImageImportProvider()
        let result = try await provider.process(data: imageData, filename: "test.png") { _ in }

        #expect(result.source == .image)
        #expect(result.mimeType == "image/png")
        #expect(result.ocrText != nil)
        // OCR may not perfectly match, just check it produced something
        #expect(!result.body.isEmpty)
    }

    @Test("Returns empty body for blank image")
    func blankImage() async throws {
        guard let imageData = createBlankImage() else {
            Issue.record("Could not create blank image")
            return
        }

        let provider = ImageImportProvider()
        let result = try await provider.process(data: imageData, filename: "blank.png") { _ in }

        #expect(result.source == .image)
        #expect(result.title == "blank")
        #expect(result.body.isEmpty)
        #expect(result.ocrText == nil)
    }

    @Test("Throws on empty data")
    func emptyData() async {
        let provider = ImageImportProvider()
        do {
            _ = try await provider.process(data: Data(), filename: "empty.png") { _ in }
            Issue.record("Expected ImportError.emptyFile")
        } catch {
            #expect(error is ImportError)
        }
    }

    // MARK: - Helpers

    private func createImageWithText(_ text: String) -> Data? {
        let width = 400
        let height = 100
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // White background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw black text
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 36, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let frameSetter = CTFramesetterCreateWithAttributedString(attrString)
        let path = CGPath(rect: CGRect(x: 10, y: 10, width: width - 20, height: height - 20), transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: 0), path, nil)
        CTFrameDraw(frame, context)

        guard let cgImage = context.makeImage() else { return nil }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData as CFMutableData, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return mutableData as Data
    }

    private func createBlankImage() -> Data? {
        let width = 100
        let height = 100
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let cgImage = context.makeImage() else { return nil }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData as CFMutableData, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return mutableData as Data
    }
}

// MARK: - DOCX Import Provider Tests

@Suite("DocxImportProvider")
struct DocxImportProviderTests {

    @Test("Supports docx type")
    func supportedTypes() {
        let types = DocxImportProvider.supportedTypes
        #expect(types.count == 1)
        #expect(types.first?.preferredFilenameExtension == "docx")
    }

    @Test("Throws on empty data")
    func emptyData() async {
        let provider = DocxImportProvider()
        do {
            _ = try await provider.process(data: Data(), filename: "empty.docx") { _ in }
            Issue.record("Expected ImportError.emptyFile")
        } catch {
            #expect(error is ImportError)
        }
    }

    @Test("Throws on invalid DOCX data")
    func invalidData() async {
        let provider = DocxImportProvider()
        let badData = "not a docx file".data(using: .utf8)!
        do {
            _ = try await provider.process(data: badData, filename: "bad.docx") { _ in }
            Issue.record("Expected ImportError.parseFailed")
        } catch {
            #expect(error is ImportError)
        }
    }
}

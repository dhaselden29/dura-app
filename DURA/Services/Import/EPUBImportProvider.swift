import Foundation
import UniformTypeIdentifiers
import Compression

struct EPUBImportProvider: ImportProvider {
    static let supportedTypes: [UTType] = [
        UTType(filenameExtension: "epub")!,
    ]

    func process(data: Data, filename: String, progress: @Sendable (Double) -> Void) async throws -> ImportResult {
        guard !data.isEmpty else { throw ImportError.emptyFile }

        progress(0.1)

        // Extract ZIP contents
        let entries: [String: Data]
        do {
            entries = try ZipReader.read(data: data)
        } catch {
            throw ImportError.parseFailed("Failed to read EPUB archive: \(error.localizedDescription)")
        }

        progress(0.3)

        // Parse container.xml to find OPF path
        guard let containerData = entries["META-INF/container.xml"],
              let containerXML = String(data: containerData, encoding: .utf8) else {
            throw ImportError.parseFailed("Missing META-INF/container.xml")
        }

        guard let opfPath = extractOPFPath(from: containerXML) else {
            throw ImportError.parseFailed("Could not find OPF path in container.xml")
        }

        // Parse OPF
        guard let opfData = entries[opfPath],
              let opfXML = String(data: opfData, encoding: .utf8) else {
            throw ImportError.parseFailed("Could not read OPF file at \(opfPath)")
        }

        let opfDir = (opfPath as NSString).deletingLastPathComponent

        let title = extractDCTitle(from: opfXML) ?? filenameStem(filename)
        let manifest = parseManifest(from: opfXML)
        let spineIDs = parseSpine(from: opfXML)

        progress(0.5)

        // Extract chapters in spine order
        var chapters: [String] = []
        for (index, spineID) in spineIDs.enumerated() {
            guard let href = manifest[spineID] else { continue }

            let fullPath = opfDir.isEmpty ? href : "\(opfDir)/\(href)"
            guard let chapterData = entries[fullPath],
                  let chapterHTML = String(data: chapterData, encoding: .utf8) else { continue }

            let markdown = HTMLMarkdownConverter.convert(chapterHTML)
            let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            chapters.append("## Chapter \(index + 1)\n\n\(trimmed)")

            let chapterProgress = 0.5 + 0.4 * Double(index + 1) / Double(spineIDs.count)
            progress(chapterProgress)
        }

        let body = chapters.joined(separator: "\n\n---\n\n")

        progress(1.0)

        return ImportResult(
            title: title,
            body: body,
            source: .markdown,
            originalFilename: filename,
            originalData: data,
            mimeType: "application/epub+zip"
        )
    }

    // MARK: - OPF Parsing

    private func extractOPFPath(from containerXML: String) -> String? {
        // Match <rootfile full-path="..." .../>
        let pattern = "full-path=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: containerXML, range: NSRange(containerXML.startIndex..., in: containerXML)) else {
            return nil
        }
        guard let range = Range(match.range(at: 1), in: containerXML) else { return nil }
        return String(containerXML[range])
    }

    private func extractDCTitle(from opfXML: String) -> String? {
        let pattern = "<dc:title[^>]*>(.*?)</dc:title>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: opfXML, range: NSRange(opfXML.startIndex..., in: opfXML)) else {
            return nil
        }
        guard let range = Range(match.range(at: 1), in: opfXML) else { return nil }
        let title = String(opfXML[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    /// Returns [id: href] from OPF manifest.
    private func parseManifest(from opfXML: String) -> [String: String] {
        var manifest: [String: String] = [:]
        let pattern = "<item\\s+[^>]*id=\"([^\"]+)\"[^>]*href=\"([^\"]+)\"[^>]*/>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return manifest }

        let matches = regex.matches(in: opfXML, range: NSRange(opfXML.startIndex..., in: opfXML))
        for match in matches {
            if let idRange = Range(match.range(at: 1), in: opfXML),
               let hrefRange = Range(match.range(at: 2), in: opfXML) {
                manifest[String(opfXML[idRange])] = String(opfXML[hrefRange])
            }
        }

        // Also try format where href comes before id
        let pattern2 = "<item\\s+[^>]*href=\"([^\"]+)\"[^>]*id=\"([^\"]+)\"[^>]*/>"
        if let regex2 = try? NSRegularExpression(pattern: pattern2, options: .caseInsensitive) {
            let matches2 = regex2.matches(in: opfXML, range: NSRange(opfXML.startIndex..., in: opfXML))
            for match in matches2 {
                if let hrefRange = Range(match.range(at: 1), in: opfXML),
                   let idRange = Range(match.range(at: 2), in: opfXML) {
                    let id = String(opfXML[idRange])
                    if manifest[id] == nil {
                        manifest[id] = String(opfXML[hrefRange])
                    }
                }
            }
        }

        return manifest
    }

    /// Returns ordered list of item IDs from OPF spine.
    private func parseSpine(from opfXML: String) -> [String] {
        var ids: [String] = []
        let pattern = "<itemref\\s+[^>]*idref=\"([^\"]+)\"[^>]*/>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return ids }

        let matches = regex.matches(in: opfXML, range: NSRange(opfXML.startIndex..., in: opfXML))
        for match in matches {
            if let range = Range(match.range(at: 1), in: opfXML) {
                ids.append(String(opfXML[range]))
            }
        }
        return ids
    }
}

// MARK: - Minimal ZIP Reader

/// Reads ZIP archives using Foundation + Compression framework.
/// Supports Store (method 0) and Deflate (method 8).
struct ZipReader {

    enum ZipError: Error {
        case invalidArchive
        case unsupportedCompression(UInt16)
        case decompressionFailed
    }

    /// Extract all entries from a ZIP archive.
    static func read(data: Data) throws -> [String: Data] {
        var entries: [String: Data] = [:]

        // Find End of Central Directory record
        guard let eocdOffset = findEOCD(in: data) else {
            throw ZipError.invalidArchive
        }

        let centralDirOffset = data.readUInt32LE(at: eocdOffset + 16)
        let entryCount = data.readUInt16LE(at: eocdOffset + 10)

        var offset = Int(centralDirOffset)

        for _ in 0..<entryCount {
            guard offset + 46 <= data.count else { break }

            // Central directory file header signature
            let sig = data.readUInt32LE(at: offset)
            guard sig == 0x02014b50 else { break }

            let compressionMethod = data.readUInt16LE(at: offset + 10)
            let compressedSize = Int(data.readUInt32LE(at: offset + 20))
            let uncompressedSize = Int(data.readUInt32LE(at: offset + 24))
            let nameLength = Int(data.readUInt16LE(at: offset + 28))
            let extraLength = Int(data.readUInt16LE(at: offset + 30))
            let commentLength = Int(data.readUInt16LE(at: offset + 32))
            let localHeaderOffset = Int(data.readUInt32LE(at: offset + 42))

            // Read filename
            let nameStart = offset + 46
            guard nameStart + nameLength <= data.count else { break }
            let nameData = data[nameStart..<(nameStart + nameLength)]
            let name = String(data: nameData, encoding: .utf8) ?? ""

            // Skip directories
            if !name.hasSuffix("/") && uncompressedSize > 0 {
                // Read from local file header
                guard localHeaderOffset + 30 <= data.count else { break }
                let localNameLen = Int(data.readUInt16LE(at: localHeaderOffset + 26))
                let localExtraLen = Int(data.readUInt16LE(at: localHeaderOffset + 28))
                let dataStart = localHeaderOffset + 30 + localNameLen + localExtraLen

                guard dataStart + compressedSize <= data.count else { break }
                let compressedData = data[dataStart..<(dataStart + compressedSize)]

                switch compressionMethod {
                case 0: // Store
                    entries[name] = Data(compressedData)
                case 8: // Deflate
                    if let decompressed = decompress(Data(compressedData), expectedSize: uncompressedSize) {
                        entries[name] = decompressed
                    }
                default:
                    // Skip unsupported compression methods
                    break
                }
            }

            offset = nameStart + nameLength + extraLength + commentLength
        }

        return entries
    }

    /// Find the End of Central Directory record by scanning backwards.
    private static func findEOCD(in data: Data) -> Int? {
        // EOCD signature: 0x06054b50
        // Minimum EOCD size is 22 bytes
        let minSize = 22
        guard data.count >= minSize else { return nil }

        // Scan backwards from end of file
        let maxCommentSize = min(65535 + minSize, data.count)
        for i in stride(from: data.count - minSize, through: max(0, data.count - maxCommentSize), by: -1) {
            if data.readUInt32LE(at: i) == 0x06054b50 {
                return i
            }
        }
        return nil
    }

    /// Decompress deflated data using the Compression framework.
    private static func decompress(_ data: Data, expectedSize: Int) -> Data? {
        // The Compression framework's COMPRESSION_ZLIB expects raw deflate
        let bufferSize = max(expectedSize, 1024)
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }

        let decodedSize = data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) -> Int in
            guard let baseAddress = sourceBuffer.baseAddress else { return 0 }
            return compression_decode_buffer(
                destinationBuffer, bufferSize,
                baseAddress.assumingMemoryBound(to: UInt8.self), data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decodedSize > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: decodedSize)
    }
}

// MARK: - Data Extensions for ZIP Parsing

extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return self.withUnsafeBytes { buffer in
            let ptr = buffer.baseAddress!.advanced(by: offset)
            return ptr.loadUnaligned(as: UInt16.self)
        }
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return self.withUnsafeBytes { buffer in
            let ptr = buffer.baseAddress!.advanced(by: offset)
            return ptr.loadUnaligned(as: UInt32.self)
        }
    }
}

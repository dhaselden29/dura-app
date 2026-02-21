import AVFoundation
import Foundation

/// Extracts an audio segment from a remote podcast episode URL.
/// Uses AVURLAsset + AVAssetExportSession to clip a time range.
struct AudioSegmentExporter: Sendable {

    enum ExportError: LocalizedError {
        case invalidURL
        case exportFailed(String)
        case noCompatiblePreset

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Invalid audio URL."
            case .exportFailed(let reason): "Audio export failed: \(reason)"
            case .noCompatiblePreset: "No compatible export preset for this audio."
            }
        }
    }

    /// Extract an audio segment centered on `position` with the given `duration`.
    /// Returns a local file URL to the exported M4A segment.
    func exportSegment(
        from audioURLString: String,
        position: Double,
        duration: Double
    ) async throws -> URL {
        guard let audioURL = URL(string: audioURLString) else {
            throw ExportError.invalidURL
        }

        let asset = AVURLAsset(url: audioURL)

        // Calculate time range: position ± duration/2
        let halfDuration = duration / 2.0
        let startSeconds = max(0, position - halfDuration)
        let endSeconds = position + halfDuration

        let startTime = CMTime(seconds: startSeconds, preferredTimescale: 600)
        let endTime = CMTime(seconds: endSeconds, preferredTimescale: 600)

        // Clamp end time to actual asset duration
        let assetDuration = try await asset.load(.duration)
        let clampedEnd = min(endTime, assetDuration)
        let clampedRange = CMTimeRange(start: startTime, end: clampedEnd)

        // Output to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "podcast-clip-\(UUID().uuidString).m4a"
        let outputURL = tempDir.appendingPathComponent(filename)

        // Use the modern async export API (macOS 15+)
        let composition = AVMutableComposition()
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw ExportError.exportFailed("No audio track found")
        }

        let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        try compositionTrack?.insertTimeRange(clampedRange, of: track, at: .zero)

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw ExportError.noCompatiblePreset
        }

        try await exportSession.export(to: outputURL, as: .m4a)
        return outputURL
    }
}

#if os(macOS)
import Foundation
import SwiftData

/// Orchestrates the full podcast clip pipeline:
/// capture → resolve → extract → transcribe → createNote
@MainActor @Observable
final class PodcastClipProcessor {
    let dataService: DataService

    private let nowPlayingService = NowPlayingService()
    private let resolverService = PodcastResolverService()
    private let segmentExporter = AudioSegmentExporter()
    private let transcriptionService = SpeechTranscriptionService()

    var isCapturing = false
    var lastError: String?

    init(dataService: DataService) {
        self.dataService = dataService
    }

    /// Capture the currently playing podcast and run the full pipeline.
    func capture(clipDuration: Double = 60) async {
        guard !isCapturing else { return }
        isCapturing = true
        lastError = nil

        defer { isCapturing = false }

        // Step 1: Get now-playing info
        guard let nowPlaying = await nowPlayingService.getCurrentlyPlaying() else {
            lastError = "No media currently playing."
            return
        }

        // Step 2: Create PodcastClip with pending status
        let clip = dataService.createPodcastClip(
            episodeTitle: nowPlaying.title,
            podcastName: nowPlaying.artist,
            playbackPosition: nowPlaying.elapsedTime,
            clipDuration: clipDuration,
            artworkData: nowPlaying.artworkData
        )
        try? dataService.save()

        // Step 3: Resolve metadata (non-fatal — clip still useful without it)
        await resolve(clip: clip)

        // Step 4: Extract audio segment + transcribe (if we have an audio URL)
        if let audioURL = clip.episodeAudioURL {
            await extractAndTranscribe(clip: clip, audioURL: audioURL)
        }

        // Step 5: Create linked note
        createNote(for: clip)

        try? dataService.save()
    }

    // MARK: - Pipeline Steps

    private func resolve(clip: PodcastClip) async {
        do {
            let resolved = try await resolverService.resolve(
                podcastName: clip.podcastName,
                episodeTitle: clip.episodeTitle
            )
            clip.feedURL = resolved.feedURL
            clip.episodeAudioURL = resolved.audioURL
            clip.sourceURL = resolved.sourceURL
            clip.processingStatus = .resolved
            try? dataService.save()
        } catch {
            // Resolution failure is non-fatal — the clip is still useful
            clip.processingStatus = .failed
            lastError = error.localizedDescription
        }
    }

    private func extractAndTranscribe(clip: PodcastClip, audioURL: String) async {
        // Extract audio segment
        var segmentURL: URL?
        do {
            segmentURL = try await segmentExporter.exportSegment(
                from: audioURL,
                position: clip.playbackPosition,
                duration: clip.clipDuration
            )
        } catch {
            // Extraction failure is non-fatal
            lastError = error.localizedDescription
        }

        // Transcribe if we got a segment
        if let segmentURL {
            do {
                let transcript = try await transcriptionService.transcribe(url: segmentURL)
                clip.transcript = transcript
            } catch {
                // Transcription failure is non-fatal
                lastError = error.localizedDescription
            }
        }
    }

    private func createNote(for clip: PodcastClip) {
        let timestamp = formatTimestamp(clip.playbackPosition)
        var bodyLines: [String] = []

        bodyLines.append("## Podcast Clip")
        bodyLines.append("")
        bodyLines.append("**Episode:** \(clip.episodeTitle)")
        bodyLines.append("**Podcast:** \(clip.podcastName)")
        bodyLines.append("**Timestamp:** \(timestamp)")
        bodyLines.append("")

        if let sourceURL = clip.sourceURL, !sourceURL.isEmpty {
            bodyLines.append("[Open Episode](\(sourceURL))")
            bodyLines.append("")
        }

        if let transcript = clip.transcript, !transcript.isEmpty {
            bodyLines.append("### Transcript")
            bodyLines.append("")
            bodyLines.append(transcript)
            bodyLines.append("")
        }

        if let notes = clip.userNotes, !notes.isEmpty {
            bodyLines.append("### Notes")
            bodyLines.append("")
            bodyLines.append(notes)
        }

        let note = dataService.createNote(
            title: "\u{1F399}\u{FE0F} \(clip.episodeTitle) — \(clip.podcastName)",
            body: bodyLines.joined(separator: "\n"),
            source: .podcast
        )

        clip.note = note
    }

    // MARK: - Helpers

    private func formatTimestamp(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
#endif

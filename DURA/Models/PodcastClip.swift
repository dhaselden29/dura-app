import Foundation
import SwiftData

/// Processing status for a podcast clip's metadata resolution pipeline.
enum ClipProcessingStatus: String, Codable {
    case pending
    case resolved
    case failed
}

/// A captured reference to a moment in a podcast episode, resolved via
/// the iTunes Search API and RSS feed parsing.
@Model
final class PodcastClip {
    var id: UUID = UUID()
    var capturedAt: Date = Date()
    var episodeTitle: String = ""
    var podcastName: String = ""
    var artworkData: Data?
    var playbackPosition: Double = 0
    var clipDuration: Double = 60
    var feedURL: String?
    var episodeAudioURL: String?
    var sourceURL: String?
    var transcript: String?
    var userNotes: String?
    var processingStatusRaw: String = ClipProcessingStatus.pending.rawValue

    @Relationship(inverse: \Note.podcastClip)
    var note: Note?

    var processingStatus: ClipProcessingStatus {
        get { ClipProcessingStatus(rawValue: processingStatusRaw) ?? .pending }
        set { processingStatusRaw = newValue.rawValue }
    }

    init(
        episodeTitle: String,
        podcastName: String,
        playbackPosition: Double,
        clipDuration: Double = 60,
        artworkData: Data? = nil
    ) {
        self.id = UUID()
        self.capturedAt = Date()
        self.episodeTitle = episodeTitle
        self.podcastName = podcastName
        self.playbackPosition = playbackPosition
        self.clipDuration = clipDuration
        self.artworkData = artworkData
        self.processingStatusRaw = ClipProcessingStatus.pending.rawValue
    }
}

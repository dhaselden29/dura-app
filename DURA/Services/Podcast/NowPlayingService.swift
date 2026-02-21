#if os(macOS)
import Foundation

/// Information about the currently playing media from any app (e.g. Apple Podcasts).
/// Retrieved via the private MediaRemote framework.
struct NowPlayingInfo: Sendable {
    let title: String
    let artist: String       // podcast name
    let elapsedTime: Double  // seconds into episode
    let artworkData: Data?
}

/// Reads the system-wide now-playing info using the private MediaRemote framework.
///
/// **APP STORE WARNING:** This is the single file to swap for App Store compliance.
/// Replace the `MediaRemoteBridge` call with a manual-entry UI or share-link parser.
/// Everything downstream (PodcastClip model, processor, UI) stays unchanged.
struct NowPlayingService: Sendable {

    func getCurrentlyPlaying() async -> NowPlayingInfo? {
        await withCheckedContinuation { continuation in
            MediaRemoteBridge.getNowPlayingInfo { info in
                guard let info else {
                    continuation.resume(returning: nil)
                    return
                }

                // MediaRemote dictionary keys (string literals — no public constants)
                let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String
                let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String
                let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double
                let artwork = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data

                guard let title, let artist else {
                    continuation.resume(returning: nil)
                    return
                }

                let result = NowPlayingInfo(
                    title: title,
                    artist: artist,
                    elapsedTime: elapsed ?? 0,
                    artworkData: artwork
                )
                continuation.resume(returning: result)
            }
        }
    }
}
#endif

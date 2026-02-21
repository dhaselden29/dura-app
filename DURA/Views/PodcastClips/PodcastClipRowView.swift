import SwiftUI

struct PodcastClipRowView: View {
    let clip: PodcastClip

    var body: some View {
        HStack(spacing: 12) {
            // Artwork thumbnail (40x40)
            artworkView
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.episodeTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text(clip.podcastName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTimestamp(clip.playbackPosition))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                statusBadge
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Artwork

    @ViewBuilder
    private var artworkView: some View {
        if let artworkData = clip.artworkData {
            #if canImport(AppKit)
            if let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                artworkPlaceholder
            }
            #else
            if let image = UIImage(data: artworkData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                artworkPlaceholder
            }
            #endif
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "headphones")
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color) = statusInfo
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var statusInfo: (String, Color) {
        switch clip.processingStatus {
        case .pending: ("Pending", .orange)
        case .resolved: ("Resolved", .green)
        case .failed: ("Failed", .red)
        }
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

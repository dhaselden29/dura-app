import Foundation

/// Resolves podcast episode metadata from captured now-playing info.
///
/// Pipeline:
/// 1. iTunes Search API — find podcast by name, get `feedUrl`
/// 2. RSS Feed — fetch and parse, match episode by title
/// 3. Extract enclosure URL (audio) and episode link
struct PodcastResolverService: Sendable {

    enum ResolverError: LocalizedError {
        case podcastNotFound
        case feedFetchFailed
        case episodeNotFound
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .podcastNotFound: "Podcast not found in iTunes Search."
            case .feedFetchFailed: "Failed to fetch podcast RSS feed."
            case .episodeNotFound: "Episode not found in RSS feed."
            case .networkError(let reason): "Network error: \(reason)"
            }
        }
    }

    struct ResolvedEpisode: Sendable {
        let feedURL: String
        let audioURL: String?
        let sourceURL: String?
    }

    /// Search iTunes for the podcast and resolve episode metadata.
    func resolve(podcastName: String, episodeTitle: String) async throws -> ResolvedEpisode {
        // Step 1: iTunes Search API
        let feedURL = try await searchITunes(podcastName: podcastName)

        // Step 2: Fetch and parse RSS feed
        let episodes = try await fetchFeed(url: feedURL)

        // Step 3: Match episode by title (fuzzy)
        let matched = episodes.first { episode in
            episode.title.localizedCaseInsensitiveContains(episodeTitle) ||
            episodeTitle.localizedCaseInsensitiveContains(episode.title)
        }

        guard let matched else {
            throw ResolverError.episodeNotFound
        }

        return ResolvedEpisode(
            feedURL: feedURL,
            audioURL: matched.audioURL,
            sourceURL: matched.link
        )
    }

    // MARK: - iTunes Search

    private func searchITunes(podcastName: String) async throws -> String {
        guard let encoded = podcastName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&media=podcast&entity=podcast&limit=5")
        else {
            throw ResolverError.podcastNotFound
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ResolverError.networkError("iTunes Search returned non-200 status")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else {
            throw ResolverError.podcastNotFound
        }

        // Find best match by name
        for result in results {
            if let feedUrl = result["feedUrl"] as? String,
               let collectionName = result["collectionName"] as? String,
               collectionName.localizedCaseInsensitiveContains(podcastName) {
                return feedUrl
            }
        }

        // Fallback: take first result with a feed URL
        if let first = results.first, let feedUrl = first["feedUrl"] as? String {
            return feedUrl
        }

        throw ResolverError.podcastNotFound
    }

    // MARK: - RSS Feed

    private func fetchFeed(url feedURL: String) async throws -> [RSSEpisode] {
        guard let url = URL(string: feedURL) else {
            throw ResolverError.feedFetchFailed
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ResolverError.feedFetchFailed
        }

        let parser = RSSFeedParser()
        let episodes = parser.parse(data: data)

        if episodes.isEmpty {
            throw ResolverError.episodeNotFound
        }

        return episodes
    }
}

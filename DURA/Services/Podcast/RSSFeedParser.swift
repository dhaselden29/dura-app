import Foundation

/// A single episode parsed from an RSS feed.
struct RSSEpisode: Sendable {
    let title: String
    let audioURL: String?
    let duration: String?
    let link: String?
    let pubDate: String?
}

/// Parses podcast RSS feeds to extract episode metadata.
/// Uses `XMLParser` with delegate pattern (same approach as `HTMLMarkdownConverter`).
final class RSSFeedParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private var episodes: [RSSEpisode] = []
    private var currentElement = ""
    private var isInsideItem = false
    private var isInsideChannel = true

    // Current item fields
    private var currentTitle = ""
    private var currentAudioURL: String?
    private var currentDuration: String?
    private var currentLink = ""
    private var currentPubDate = ""

    /// Parse RSS XML data and return an array of episodes.
    func parse(data: Data) -> [RSSEpisode] {
        episodes = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return episodes
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName

        if elementName == "item" {
            isInsideItem = true
            currentTitle = ""
            currentAudioURL = nil
            currentDuration = nil
            currentLink = ""
            currentPubDate = ""
        }

        // <enclosure url="..." type="audio/mpeg" />
        if elementName == "enclosure", isInsideItem {
            if let url = attributeDict["url"] {
                let type = attributeDict["type"] ?? ""
                if type.hasPrefix("audio/") || url.hasSuffix(".mp3") || url.hasSuffix(".m4a") {
                    currentAudioURL = url
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }

        switch currentElement {
        case "title":
            currentTitle += string
        case "itunes:duration":
            currentDuration = (currentDuration ?? "") + string
        case "link":
            currentLink += string
        case "pubDate":
            currentPubDate += string
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "item" {
            let episode = RSSEpisode(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                audioURL: currentAudioURL,
                duration: currentDuration?.trimmingCharacters(in: .whitespacesAndNewlines),
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            episodes.append(episode)
            isInsideItem = false
        }
        currentElement = ""
    }
}

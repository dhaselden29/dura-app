import SwiftUI

struct ArticleRowView: View {
    let article: Note
    let dataService: DataService

    private var domain: String? {
        guard let urlString = article.sourceURL,
              let url = URL(string: urlString),
              let host = url.host() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var annotationCount: Int {
        article.highlights.filter { $0.isComment }.count
    }

    private var sourceIcon: String {
        switch article.source {
        case .pdf: "doc.richtext"
        case .web: "globe"
        case .markdown: "doc.text"
        case .plainText: "doc.plaintext"
        case .rtf: "doc.text.fill"
        case .docx: "doc.fill"
        case .image: "photo"
        case .audio: "waveform"
        case .podcast: "headphones"
        default: "doc.richtext"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: sourceIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(article.title.isEmpty ? "Untitled" : article.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    if article.isInReadingList {
                        Image(systemName: "bookmark.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    if annotationCount > 0 {
                        Label("\(annotationCount)", systemImage: "text.bubble")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if !article.body.isEmpty {
                    Text(String(article.body.prefix(120)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let domain {
                        Text(domain)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Text(article.source.displayName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if let tags = article.tags, !tags.isEmpty {
                        Text(tags.prefix(3).map { "#\($0.name)" }.joined(separator: " "))
                            .font(.caption)
                            .foregroundStyle(.blue.opacity(0.7))
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                if article.isInReadingList {
                    dataService.removeFromReadingList(article)
                } else {
                    dataService.addToReadingList(article)
                }
            } label: {
                Label(
                    article.isInReadingList ? "Remove from Reading List" : "Add to Reading List",
                    systemImage: article.isInReadingList ? "bookmark.slash" : "bookmark"
                )
            }

            if let urlString = article.sourceURL, let url = URL(string: urlString) {
                Button {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #else
                    UIApplication.shared.open(url)
                    #endif
                } label: {
                    Label("Open Source URL", systemImage: "safari")
                }
            }

            Divider()

            Button(role: .destructive) {
                dataService.deleteNote(article)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

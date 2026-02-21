import SwiftUI

struct BookmarkRowView: View {
    let bookmark: Bookmark
    let onToggleRead: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Read/unread indicator
            Image(systemName: bookmark.isRead ? "circle" : "circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(bookmark.isRead ? Color.secondary : Color.blue)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                // Title + domain
                HStack {
                    Text(bookmark.title.isEmpty ? bookmark.url : bookmark.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text(bookmark.domain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Excerpt
                if let excerpt = bookmark.excerpt, !excerpt.isEmpty {
                    Text(String(excerpt.prefix(120)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Metadata row
                HStack(spacing: 8) {
                    Text(bookmark.addedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if let tags = bookmark.tags, !tags.isEmpty {
                        ForEach(tags.prefix(3)) { tag in
                            Text(tag.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                openInBrowser()
            } label: {
                Label("Open in Browser", systemImage: "safari")
            }

            Button {
                onToggleRead()
            } label: {
                Label(
                    bookmark.isRead ? "Mark as Unread" : "Mark as Read",
                    systemImage: bookmark.isRead ? "circle.fill" : "circle"
                )
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func openInBrowser() {
        guard let url = URL(string: bookmark.url) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }
}

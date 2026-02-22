import SwiftUI
import SwiftData

struct BookmarkRowView: View {
    let bookmark: Bookmark
    let dataService: DataService
    let onToggleRead: () -> Void
    let onDelete: () -> Void

    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var showingTagPicker = false
    @State private var newTagName = ""

    var body: some View {
        HStack(spacing: 8) {
            // Unread indicator (analogous to pin indicator in NoteRowView)
            if !bookmark.isRead {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(bookmark.title.isEmpty ? bookmark.url : bookmark.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()
                }

                if let excerpt = bookmark.excerpt, !excerpt.isEmpty {
                    Text(String(excerpt.prefix(120)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Label(bookmark.domain, systemImage: "globe")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if let tags = bookmark.tags, !tags.isEmpty {
                        Text(tags.prefix(3).map { "#\($0.name)" }.joined(separator: " "))
                            .font(.caption)
                            .foregroundStyle(.blue.opacity(0.7))
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
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

            Button {
                showingTagPicker = true
            } label: {
                Label("Manage Tags…", systemImage: "tag")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .popover(isPresented: $showingTagPicker) {
            tagPicker
        }
    }

    // MARK: - Tag Picker

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Manage Tags")
                .font(.headline)
                .padding()

            // Current tags with remove buttons
            if let tags = bookmark.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(tags) { tag in
                            HStack(spacing: 2) {
                                Text("#\(tag.name)")
                                    .font(.caption)
                                Button {
                                    dataService.removeTag(tag, from: bookmark)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }

            HStack {
                TextField("New tag...", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addNewTag()
                    }
                Button("Add") {
                    addNewTag()
                }
                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)

            List {
                let assignedTagIDs = Set(bookmark.tags?.map(\.id) ?? [])
                ForEach(allTags.filter { !assignedTagIDs.contains($0.id) }) { tag in
                    Button {
                        dataService.addTag(tag, to: bookmark)
                    } label: {
                        Label(tag.name, systemImage: "tag")
                    }
                }
            }
            .frame(minWidth: 200, minHeight: 200)
        }
    }

    // MARK: - Actions

    private func addNewTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let tag = try? dataService.findOrCreateTag(name: name) {
            dataService.addTag(tag, to: bookmark)
        }
        newTagName = ""
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

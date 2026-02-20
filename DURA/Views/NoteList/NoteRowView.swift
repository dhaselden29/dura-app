import SwiftUI

struct NoteRowView: View {
    let note: Note
    let dataService: DataService

    var body: some View {
        HStack(spacing: 8) {
            // Pin indicator
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }

                    if note.isDraft {
                        Text(note.kanbanStatus.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                if !note.body.isEmpty {
                    Text(String(note.body.prefix(120)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(note.modifiedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if let notebook = note.notebook {
                        Label(notebook.name, systemImage: notebook.icon ?? "folder")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if let tags = note.tags, !tags.isEmpty {
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
                dataService.togglePin(note)
            } label: {
                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
            }

            Button {
                dataService.toggleFavorite(note)
            } label: {
                Label(note.isFavorite ? "Unfavorite" : "Favorite", systemImage: note.isFavorite ? "star.slash" : "star")
            }

            Divider()

            if note.isDraft {
                Button {
                    dataService.demoteFromDraft(note)
                } label: {
                    Label("Remove from Drafts", systemImage: "doc.text.below.ecg")
                }
            } else {
                Button {
                    dataService.promoteToDraft(note)
                } label: {
                    Label("Promote to Draft", systemImage: "doc.text")
                }
            }

            Divider()

            Button(role: .destructive) {
                dataService.deleteNote(note)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

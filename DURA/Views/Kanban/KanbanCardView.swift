import SwiftUI

struct KanbanCardView: View {
    let note: Note
    let isSelected: Bool
    let isConnected: Bool
    let dataService: DataService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row with pin/star indicators
            HStack(spacing: 4) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if note.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }

            // Body preview
            if !note.body.isEmpty {
                Text(String(note.body.prefix(80)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Notebook + tags row
            HStack(spacing: 6) {
                if let notebook = note.notebook {
                    Label(notebook.name, systemImage: notebook.icon ?? "folder")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if let tags = note.tags, !tags.isEmpty {
                    Text(tags.prefix(2).map { "#\($0.name)" }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundStyle(.blue.opacity(0.7))
                }

                Spacer()

                // Relative time
                Text(note.modifiedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Color.accentColor :
                    isConnected ? Color.accentColor.opacity(0.3) :
                    Color.secondary.opacity(0.2),
                    lineWidth: isSelected ? 2 : isConnected ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
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

            Menu("Move to") {
                ForEach(KanbanStatus.boardStatuses) { status in
                    Button {
                        dataService.setKanbanStatus(status, for: note)
                    } label: {
                        Label(status.displayName, systemImage: status.iconName)
                    }
                    .disabled(note.kanbanStatus == status)
                }
            }

            Divider()

            Button {
                dataService.demoteFromDraft(note)
            } label: {
                Label("Remove from Drafts", systemImage: "doc.text.below.ecg")
            }

            Button(role: .destructive) {
                dataService.deleteNote(note)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

import SwiftUI
import SwiftData

struct NoteListContentView: View {
    @Binding var selectedNote: Note?
    let sidebarSelection: SidebarItem?
    let dataService: DataService

    @Query(sort: \Note.modifiedAt, order: .reverse) private var allNotes: [Note]
    @State private var searchText = ""
    @State private var sortOrder: NoteSortOrder = .modifiedDescending

    var body: some View {
        List(filteredNotes, selection: $selectedNote) { note in
            NoteRowView(note: note, dataService: dataService)
                .tag(note)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        dataService.deleteNote(note)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        dataService.toggleFavorite(note)
                    } label: {
                        Label(
                            note.isFavorite ? "Unfavorite" : "Favorite",
                            systemImage: note.isFavorite ? "star.slash" : "star"
                        )
                    }
                    .tint(.yellow)

                    Button {
                        dataService.togglePin(note)
                    } label: {
                        Label(
                            note.isPinned ? "Unpin" : "Pin",
                            systemImage: note.isPinned ? "pin.slash" : "pin"
                        )
                    }
                    .tint(.orange)
                }
        }
        .searchable(text: $searchText, prompt: "Search notes...")
        .navigationTitle(sidebarSelection?.title ?? "Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNote) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(NoteSortOrder.allCases) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            HStack {
                                Text(order.displayName)
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .overlay {
            if filteredNotes.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "note.text",
                        description: Text("Create a new note to get started.")
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    // MARK: - Filtering

    private var filteredNotes: [Note] {
        var notes = allNotes

        // Apply sidebar filter
        switch sidebarSelection {
        case .allNotes, .none:
            break
        case .inbox:
            notes = notes.filter { $0.notebook?.name == "Inbox" || $0.notebook == nil }
        case .favorites:
            notes = notes.filter { $0.isFavorite }
        case .drafts:
            notes = notes.filter { $0.isDraft }
        case .notebook(let nb):
            notes = notes.filter { $0.notebook?.id == nb.id }
        case .tag(let tag):
            notes = notes.filter { note in
                note.tags?.contains(where: { $0.id == tag.id }) ?? false
            }
        case .kanban, .readingList:
            break
        }

        // Apply search
        if !searchText.isEmpty {
            notes = notes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.body.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort pinned to top
        let pinned = notes.filter(\.isPinned)
        let unpinned = notes.filter { !$0.isPinned }
        return pinned + unpinned
    }

    // MARK: - Actions

    private func createNote() {
        var notebook: Notebook?
        if case .notebook(let nb) = sidebarSelection {
            notebook = nb
        }
        let note = dataService.createNote(title: "", notebook: notebook)
        selectedNote = note
    }
}

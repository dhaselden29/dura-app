import SwiftUI
import SwiftData

struct KanbanBoardView: View {
    @Binding var selectedNote: Note?
    let dataService: DataService

    @Query(sort: \Note.modifiedAt, order: .reverse) private var allNotes: [Note]

    var body: some View {
        Group {
            if allNotes.isEmpty {
                ContentUnavailableView(
                    "No Notes",
                    systemImage: "rectangle.split.3x1",
                    description: Text("Create a note to see it on the Kanban board.")
                )
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(KanbanStatus.boardStatuses) { status in
                            KanbanColumnView(
                                status: status,
                                notes: notesForStatus(status),
                                allNotes: allNotes,
                                connectedNoteIDs: connectedNoteIDs,
                                selectedNote: $selectedNote,
                                dataService: dataService,
                                startCollapsed: status == .note
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Kanban Board")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createDraft) {
                    Label("New Draft", systemImage: "plus.rectangle")
                }
            }
        }
    }

    private func notesForStatus(_ status: KanbanStatus) -> [Note] {
        allNotes.filter { $0.kanbanStatus == status }
    }

    private var connectedNoteIDs: Set<UUID> {
        guard let selected = selectedNote,
              let selectedTags = selected.tags, !selectedTags.isEmpty else {
            return []
        }
        let selectedTagIDs = Set(selectedTags.map(\.id))
        var connected = Set<UUID>()
        for note in allNotes where note.id != selected.id {
            if let tags = note.tags {
                if tags.contains(where: { selectedTagIDs.contains($0.id) }) {
                    connected.insert(note.id)
                }
            }
        }
        return connected
    }

    private func createDraft() {
        let note = dataService.createNote(title: "")
        dataService.promoteToDraft(note)
        selectedNote = note
    }
}

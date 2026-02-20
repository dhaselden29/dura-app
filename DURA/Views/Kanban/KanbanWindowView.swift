import SwiftUI
import SwiftData

struct KanbanWindowView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedNote: Note?
    @State private var dataService: DataService?

    var body: some View {
        Group {
            if let dataService {
                HSplitView {
                    KanbanBoardView(
                        selectedNote: $selectedNote,
                        dataService: dataService
                    )
                    .frame(minWidth: 600)

                    // Detail pane
                    if let selectedNote {
                        NoteDetailView(note: selectedNote, dataService: dataService)
                            .frame(minWidth: 300, idealWidth: 400)
                    } else {
                        ContentUnavailableView(
                            "Select a Card",
                            systemImage: "doc.text",
                            description: Text("Click a card on the board to view its content.")
                        )
                        .frame(minWidth: 300, idealWidth: 400)
                    }
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            if dataService == nil {
                dataService = DataService(modelContext: modelContext)
            }
        }
    }
}

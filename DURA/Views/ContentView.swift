import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedNote: Note?
    @State private var sidebarSelection: SidebarItem? = .allNotes
    @State private var dataService: DataService?

    var body: some View {
        Group {
            if let dataService {
                NavigationSplitView {
                    SidebarView(
                        selection: $sidebarSelection,
                        dataService: dataService
                    )
                } content: {
                    if sidebarSelection == .kanban {
                        KanbanBoardView(
                            selectedNote: $selectedNote,
                            dataService: dataService
                        )
                    } else if sidebarSelection == .readingList {
                        BookmarkListView(dataService: dataService)
                    } else {
                        NoteListContentView(
                            selectedNote: $selectedNote,
                            sidebarSelection: sidebarSelection,
                            dataService: dataService
                        )
                    }
                } detail: {
                    if let selectedNote {
                        NoteDetailView(note: selectedNote, dataService: dataService)
                    } else {
                        ContentUnavailableView(
                            "Select a Note",
                            systemImage: "doc.text",
                            description: Text("Choose a note from the list or create a new one.")
                        )
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

// MARK: - Sidebar Item

enum SidebarItem: Hashable {
    case allNotes
    case inbox
    case favorites
    case drafts
    case kanban
    case readingList
    case notebook(Notebook)
    case tag(Tag)

    var title: String {
        switch self {
        case .allNotes: "All Notes"
        case .inbox: "Inbox"
        case .favorites: "Favorites"
        case .drafts: "Drafts"
        case .kanban: "Kanban Board"
        case .readingList: "Reading List"
        case .notebook(let nb): nb.name
        case .tag(let tag): tag.name
        }
    }

    var iconName: String {
        switch self {
        case .allNotes: "tray.full"
        case .inbox: "tray.and.arrow.down"
        case .favorites: "star"
        case .drafts: "doc.text"
        case .kanban: "rectangle.split.3x1"
        case .readingList: "bookmark"
        case .notebook(let nb): nb.icon ?? "folder"
        case .tag: "tag"
        }
    }
}

#if os(macOS)
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            WordPressSettingsView()
                .tabItem {
                    Label("WordPress", systemImage: "globe")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("appearance") private var appearance = "dark"

    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("Dark").tag("dark")
                Text("Light").tag("light")
                Text("System").tag("system")
            }
        }
        .padding()
    }
}
#endif

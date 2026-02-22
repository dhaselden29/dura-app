import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedNote: Note?
    @State private var sidebarSelection: SidebarItem? = .allNotes
    @State private var dataService: DataService?
    #if os(macOS)
    @State private var clipWatcher: ClipFolderWatcher?
    @State private var podcastProcessor: PodcastClipProcessor?
    #endif

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
                    } else if sidebarSelection == .allArticles || sidebarSelection == .readingList {
                        ArticleListView(
                            selectedNote: $selectedNote,
                            readingListOnly: sidebarSelection == .readingList,
                            dataService: dataService
                        )
                    } else if sidebarSelection == .podcastClips {
                        PodcastClipsListView(
                            dataService: dataService,
                            selectedNote: $selectedNote
                        )
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
                let ds = DataService(modelContext: modelContext)
                dataService = ds
                #if os(macOS)
                let watcher = ClipFolderWatcher(dataService: ds)
                clipWatcher = watcher
                watcher.startWatching()
                podcastProcessor = PodcastClipProcessor(dataService: ds)
                #endif
            }
        }
        #if os(macOS)
        .onDisappear {
            clipWatcher?.stopWatching()
        }
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .automatic) {
                Button {
                    if let processor = podcastProcessor {
                        Task {
                            let duration = UserDefaults.standard.double(forKey: "podcastClipDuration")
                            await processor.capture(clipDuration: duration > 0 ? duration : 60)
                        }
                    }
                } label: {
                    Label("Capture Podcast Clip", systemImage: "headphones")
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            #endif
        }
    }
}

// MARK: - Sidebar Item

enum SidebarItem: Hashable {
    case allNotes
    case favorites
    case drafts
    case kanbanStatus(KanbanStatus)
    case kanban
    case allArticles
    case readingList
    case podcastClips
    case notebook(Notebook)
    case tag(Tag)

    var title: String {
        switch self {
        case .allNotes: "All Notes"
        case .favorites: "Favorites"
        case .drafts: "Drafts"
        case .kanbanStatus(let status): status.displayName
        case .kanban: "Kanban Board"
        case .allArticles: "All Articles"
        case .readingList: "Reading List"
        case .podcastClips: "Podcast Clips"
        case .notebook(let nb): nb.name
        case .tag(let tag): tag.name
        }
    }

    var iconName: String {
        switch self {
        case .allNotes: "tray.full"
        case .favorites: "star"
        case .drafts: "doc.text"
        case .kanbanStatus(let status): status.iconName
        case .kanban: "rectangle.split.3x1"
        case .allArticles: "doc.richtext"
        case .readingList: "bookmark"
        case .podcastClips: "headphones"
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

            ClipWatcherSettingsView()
                .tabItem {
                    Label("Web Clipper", systemImage: "paperclip")
                }

            WordPressSettingsView()
                .tabItem {
                    Label("WordPress", systemImage: "globe")
                }

            PodcastClipsSettingsView()
                .tabItem {
                    Label("Podcasts", systemImage: "headphones")
                }

            ReaderSettingsView()
                .tabItem {
                    Label("Reader", systemImage: "book")
                }
        }
        .frame(width: 500, height: 450)
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

struct ClipWatcherSettingsView: View {
    @AppStorage("clipWatchEnabled") private var isEnabled = true
    @AppStorage("clipWatchFolder") private var folderPath = ""

    var body: some View {
        Form {
            Toggle("Auto-import clipped pages", isOn: $isEnabled)

            LabeledContent("Watch folder") {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(displayPath)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 8) {
                        Button("Choose Folder...") {
                            chooseFolder()
                        }

                        if !folderPath.isEmpty {
                            Button("Reset to Default") {
                                folderPath = ""
                            }
                        }
                    }
                }
            }

            LabeledContent("How it works") {
                Text("New .md files saved to this folder by DURA Clipper are automatically imported. After import, files move to a hidden .imported subfolder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 300, alignment: .leading)
            }

            Button("Open Watch Folder in Finder") {
                NSWorkspace.shared.open(ClipFolderWatcher.watchFolderURL)
            }
        }
        .padding()
    }

    private var displayPath: String {
        if folderPath.isEmpty {
            return ClipFolderWatcher.defaultWatchFolderURL.path
                .replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
        }
        return folderPath
            .replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Watch Folder"
        panel.directoryURL = ClipFolderWatcher.watchFolderURL

        if panel.runModal() == .OK, let url = panel.url {
            folderPath = url.path
        }
    }
}
#endif

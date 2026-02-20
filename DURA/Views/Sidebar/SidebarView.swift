import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    let dataService: DataService

    @Query(sort: [SortDescriptor(\Notebook.sortOrder), SortDescriptor(\Notebook.name)])
    private var allNotebooks: [Notebook]

    @Query(sort: \Tag.name)
    private var tags: [Tag]

    @State private var isAddingNotebook = false
    @State private var newNotebookName = ""

    private var rootNotebooks: [Notebook] {
        allNotebooks.filter { $0.parentNotebook == nil }
    }

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label("All Notes", systemImage: "tray.full")
                    .tag(SidebarItem.allNotes)
                Label("Inbox", systemImage: "tray.and.arrow.down")
                    .tag(SidebarItem.inbox)
                Label("Favorites", systemImage: "star")
                    .tag(SidebarItem.favorites)
                Label("Drafts", systemImage: "doc.text")
                    .tag(SidebarItem.drafts)
            }

            Section("Notebooks") {
                ForEach(rootNotebooks) { notebook in
                    NotebookRow(notebook: notebook)
                }
                .onDelete(perform: deleteNotebooks)

                if isAddingNotebook {
                    TextField("Notebook name", text: $newNotebookName)
                        .onSubmit(commitNewNotebook)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                } else {
                    Button {
                        isAddingNotebook = true
                    } label: {
                        Label("Add Notebook", systemImage: "plus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !tags.isEmpty {
                Section("Tags") {
                    ForEach(tags) { tag in
                        Label(tag.name, systemImage: "tag")
                            .tag(SidebarItem.tag(tag))
                    }
                }
            }

            Section("Workflow") {
                Label("Kanban Board", systemImage: "rectangle.split.3x1")
                    .tag(SidebarItem.kanban)
                Label("Reading List", systemImage: "bookmark")
                    .tag(SidebarItem.readingList)
            }
        }
        .navigationTitle("DURA")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        #endif
    }

    private func commitNewNotebook() {
        let name = newNotebookName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            isAddingNotebook = false
            return
        }
        dataService.createNotebook(name: name)
        newNotebookName = ""
        isAddingNotebook = false
    }

    private func deleteNotebooks(at offsets: IndexSet) {
        let notebooks = rootNotebooks
        for index in offsets {
            dataService.deleteNotebook(notebooks[index])
        }
    }
}

struct NotebookRow: View {
    let notebook: Notebook

    var body: some View {
        let children = (notebook.children ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
        if !children.isEmpty {
            DisclosureGroup {
                ForEach(children) { child in
                    NotebookRow(notebook: child)
                }
            } label: {
                notebookLabel
            }
        } else {
            notebookLabel
        }
    }

    private var notebookLabel: some View {
        Label(notebook.name, systemImage: notebook.icon ?? "folder")
            .tag(SidebarItem.notebook(notebook))
    }
}

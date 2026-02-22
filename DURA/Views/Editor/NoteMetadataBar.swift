import SwiftUI
import SwiftData

struct NoteMetadataBar: View {
    @Bindable var note: Note
    let dataService: DataService

    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Notebook.name) private var allNotebooks: [Notebook]

    @State private var showTagPicker = false
    @State private var showNotebookPicker = false
    @State private var newTagName = ""

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Notebook chip
                Button {
                    showNotebookPicker = true
                } label: {
                    Label(
                        note.notebook?.name ?? "No Notebook",
                        systemImage: note.notebook?.icon ?? "folder"
                    )
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showNotebookPicker) {
                    notebookPicker
                }

                // Tag chips
                if let tags = note.tags {
                    ForEach(tags) { tag in
                        HStack(spacing: 2) {
                            Text("#\(tag.name)")
                                .font(.caption)
                            Button {
                                dataService.removeTag(tag, from: note)
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

                // Add tag button
                Button {
                    showTagPicker = true
                } label: {
                    Label("Add Tag", systemImage: "plus")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showTagPicker) {
                    tagPicker
                }

                // Draft badge
                if note.isDraft {
                    Text(note.kanbanStatus.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.15))
                        .clipShape(Capsule())
                }

                // WordPress status badge
                if let meta = note.draftMetadata, meta.wordpressPostId != nil {
                    Label(meta.wordpressStatus.displayName, systemImage: "globe")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.purple.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Pickers

    private var notebookPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Move to Notebook")
                .font(.headline)
                .padding()

            List {
                Button("No Notebook") {
                    dataService.moveNote(note, to: nil)
                    showNotebookPicker = false
                }

                ForEach(allNotebooks) { notebook in
                    Button {
                        dataService.moveNote(note, to: notebook)
                        showNotebookPicker = false
                    } label: {
                        Label(notebook.name, systemImage: notebook.icon ?? "folder")
                    }
                }
            }
            .frame(minWidth: 200, minHeight: 200)
        }
    }

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add Tag")
                .font(.headline)
                .padding()

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
                let assignedTagIDs = Set(note.tags?.map(\.id) ?? [])
                ForEach(allTags.filter { !assignedTagIDs.contains($0.id) }) { tag in
                    Button {
                        dataService.addTag(tag, to: note)
                    } label: {
                        Label(tag.name, systemImage: "tag")
                    }
                }
            }
            .frame(minWidth: 200, minHeight: 200)
        }
    }

    private func addNewTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let tag = try? dataService.findOrCreateTag(name: name) {
            dataService.addTag(tag, to: note)
        }
        newTagName = ""
    }
}

import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Bindable var note: Note
    let dataService: DataService

    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Notebook.name) private var allNotebooks: [Notebook]

    @State private var showTagPicker = false
    @State private var showNotebookPicker = false
    @State private var newTagName = ""
    @State private var lastKnownTitle: String?
    @State private var lastKnownBody: String?

    @State private var bodyFocusRequested = false

    // Reader theme
    @AppStorage("readerTheme") private var themeRaw: String = ReaderDefaults.theme

    // Highlights
    @State private var showHighlightsPanel = false

    // Export state
    @State private var exportProgress: Double = 0
    @State private var exportError: String?
    @State private var showExportError = false
    @State private var showFileExporter = false
    @State private var exportResult: ExportResult?

    // Publish state
    @State private var publishProgress: Double = 0
    @State private var publishError: String?
    @State private var showPublishError = false
    @State private var showPublishSuccess = false

    private var theme: ReaderTheme {
        ReaderTheme(rawValue: themeRaw) ?? .light
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Metadata bar
            metadataBar

            Divider()

            // Title field
            TextField("Title", text: $note.title)
                .font(.largeTitle.bold())
                .textFieldStyle(.plain)
                .foregroundStyle(theme.swiftUITextColor)
                .padding(.horizontal)
                .padding(.top, 12)
                .onSubmit {
                    bodyFocusRequested = true
                }

            Divider()
                .padding(.horizontal)
                .padding(.vertical, 8)

            // Block editor
            BlockEditorView(
                markdown: $note.body,
                requestFocus: $bodyFocusRequested,
                highlights: note.highlights,
                onHighlightCreated: { highlight in
                    var highlights = note.highlights
                    highlights.append(highlight)
                    note.highlights = highlights
                }
            )

            // Status bar
            statusBar
        }
        .background(theme.swiftUIBackground)
        .onAppear {
            lastKnownTitle = note.title
            lastKnownBody = note.body
        }
        .onChange(of: note.id) {
            lastKnownTitle = note.title
            lastKnownBody = note.body
        }
        .onChange(of: note.body) {
            guard note.body != lastKnownBody else { return }
            lastKnownBody = note.body
            note.modifiedAt = Date()
            if note.isDraft {
                var meta = note.draftMetadata ?? DraftMetadata()
                meta.lastLocalEditAt = Date()
                note.draftMetadata = meta
            }
        }
        .onChange(of: note.title) {
            guard note.title != lastKnownTitle else { return }
            lastKnownTitle = note.title
            note.modifiedAt = Date()
        }
        .navigationTitle(note.title.isEmpty ? "Untitled" : note.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                noteMenu
            }
        }
        #else
        .toolbar {
            ToolbarItem(placement: .automatic) {
                noteMenu
            }
        }
        #endif
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportResult.map { ExportDocument(data: $0.data, contentType: $0.utType) },
            contentType: exportResult?.utType ?? .plainText,
            defaultFilename: exportResult?.filename ?? "export"
        ) { result in
            if case .failure(let error) = result {
                exportError = error.localizedDescription
                showExportError = true
            }
            exportResult = nil
        }
        .overlay(alignment: .bottom) {
            if exportProgress > 0 && exportProgress < 1 {
                ExportProgressOverlay(progress: exportProgress)
            }
            if publishProgress > 0 && publishProgress < 1 {
                ExportProgressOverlay(progress: publishProgress, label: "Publishing...")
            }
        }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "An unknown error occurred.")
        }
        .alert("Publish Error", isPresented: $showPublishError) {
            Button("OK") { publishError = nil }
        } message: {
            Text(publishError ?? "An unknown error occurred.")
        }
        .alert("Published", isPresented: $showPublishSuccess) {
            Button("OK") {}
        } message: {
            Text("Your post has been published to WordPress.")
        }
        .sheet(isPresented: $showHighlightsPanel) {
            HighlightsPanelView(note: note)
        }
    }

    // MARK: - Metadata Bar

    private var metadataBar: some View {
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

    // MARK: - Status Bar

    private var statusBar: some View {
        let statusColor: Color = theme == .light ? .secondary : theme.swiftUITextColor.opacity(0.6)
        return HStack {
            let wordCount = note.body.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            let readingTime = max(1, wordCount / 238)
            Text("\(wordCount) words")
                .font(.caption)
                .foregroundStyle(statusColor)

            Text("\(note.body.count) characters")
                .font(.caption)
                .foregroundStyle(statusColor)

            Text("~\(readingTime) min read")
                .font(.caption)
                .foregroundStyle(statusColor)

            Spacer()

            Text("Modified \(note.modifiedAt, style: .relative) ago")
                .font(.caption)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Note Menu

    private var noteMenu: some View {
        Menu {
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

            Button {
                showHighlightsPanel = true
            } label: {
                Label("Highlights (\(note.highlights.count))", systemImage: "highlighter")
            }

            Divider()

            // Export submenu
            Menu("Export As...") {
                Button {
                    performExport(format: .markdown)
                } label: {
                    Label("Markdown (.md)", systemImage: "doc.text")
                }

                Button {
                    performExport(format: .html)
                } label: {
                    Label("HTML (.html)", systemImage: "globe")
                }

                Button {
                    performExport(format: .pdf)
                } label: {
                    Label("PDF (.pdf)", systemImage: "doc.richtext")
                }
            }

            // WordPress publish (only for drafts)
            if note.isDraft {
                Menu("Publish to WordPress") {
                    Button {
                        publishToWordPress(asDraft: false)
                    } label: {
                        Label("Publish", systemImage: "paperplane")
                    }

                    Button {
                        publishToWordPress(asDraft: true)
                    } label: {
                        Label("Save as WP Draft", systemImage: "doc.text")
                    }
                }
            }

            Divider()

            if note.isDraft {
                Menu("Kanban Status") {
                    ForEach(KanbanStatus.boardStatuses) { status in
                        Button {
                            dataService.setKanbanStatus(status, for: note)
                        } label: {
                            HStack {
                                Label(status.displayName, systemImage: status.iconName)
                                if note.kanbanStatus == status {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

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
                Label("Delete Note", systemImage: "trash")
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
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

    // MARK: - Export

    private func performExport(format: ExportFormat) {
        let service = ExportService()
        let title = note.title.isEmpty ? "Untitled" : note.title
        let markdown = note.body

        exportProgress = 0.01

        Task {
            do {
                let result = try await service.export(
                    title: title,
                    markdown: markdown,
                    format: format
                ) { progress in
                    Task { @MainActor in
                        exportProgress = progress
                    }
                }
                exportResult = result
                exportProgress = 0
                showFileExporter = true
            } catch {
                exportProgress = 0
                exportError = error.localizedDescription
                showExportError = true
            }
        }
    }

    // MARK: - WordPress Publish

    private func publishToWordPress(asDraft: Bool) {
        guard let config = WordPressCredentialStore().load() else {
            publishError = "WordPress is not configured. Go to Settings > WordPress to set up your credentials."
            showPublishError = true
            return
        }

        publishProgress = 0.01

        Task {
            do {
                let service = WordPressService()
                let updatedMeta = try await service.publishPost(
                    title: note.title,
                    markdown: note.body,
                    metadata: note.draftMetadata ?? DraftMetadata(),
                    config: config,
                    asDraft: asDraft
                ) { progress in
                    Task { @MainActor in
                        publishProgress = progress
                    }
                }
                note.draftMetadata = updatedMeta
                publishProgress = 0
                showPublishSuccess = true
                try? dataService.save()
            } catch {
                publishProgress = 0
                publishError = error.localizedDescription
                showPublishError = true
            }
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

// MARK: - Highlights Panel

struct HighlightsPanelView: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                let highlights = note.highlights.sorted { $0.rangeStart < $1.rangeStart }
                if highlights.isEmpty {
                    ContentUnavailableView(
                        "No Highlights",
                        systemImage: "highlighter",
                        description: Text("Select text in the editor and tap Highlight to add one.")
                    )
                } else {
                    List {
                        ForEach(highlights) { highlight in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(highlight.color.swiftUIColor)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(highlight.anchorText)
                                        .font(.caption)
                                        .lineLimit(2)

                                    if let annotation = highlight.annotation, !annotation.isEmpty {
                                        Text(annotation)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { indexSet in
                            var highlights = note.highlights.sorted { $0.rangeStart < $1.rangeStart }
                            highlights.remove(atOffsets: indexSet)
                            note.highlights = highlights
                        }
                    }
                }
            }
            .navigationTitle("Highlights")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 300)
    }
}

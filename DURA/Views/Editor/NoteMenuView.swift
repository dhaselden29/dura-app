import SwiftUI

/// ViewModifier that adds the note toolbar menu, file exporter, export/publish
/// progress overlays, and all related alerts. Owns all export/publish state.
struct NoteMenuModifier: ViewModifier {
    @Bindable var note: Note
    let dataService: DataService
    @Binding var showHighlightsPanel: Bool
    @Binding var showAnnotationSidebar: Bool

    @State private var exportProgress: Double = 0
    @State private var exportError: String?
    @State private var showExportError = false
    @State private var showFileExporter = false
    @State private var exportResult: ExportResult?

    @State private var publishProgress: Double = 0
    @State private var publishError: String?
    @State private var showPublishError = false
    @State private var showPublishSuccess = false

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    menu
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    menu
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
    }

    // MARK: - Menu

    private var menu: some View {
        Menu {
            if note.isArticle {
                articleMenuItems
            } else {
                noteMenuItems
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }

    // MARK: - Article Menu

    @ViewBuilder
    private var articleMenuItems: some View {
        Button {
            showAnnotationSidebar.toggle()
        } label: {
            Label(showAnnotationSidebar ? "Hide Annotations" : "Show Annotations", systemImage: "text.bubble")
        }

        Button {
            showHighlightsPanel = true
        } label: {
            Label("Highlights (\(note.highlights.count))", systemImage: "highlighter")
        }

        Divider()

        Button {
            if note.isInReadingList {
                dataService.removeFromReadingList(note)
            } else {
                dataService.addToReadingList(note)
            }
        } label: {
            Label(
                note.isInReadingList ? "Remove from Reading List" : "Add to Reading List",
                systemImage: note.isInReadingList ? "bookmark.slash" : "bookmark"
            )
        }

        if let urlString = note.sourceURL, URL(string: urlString) != nil {
            Button {
                if let url = URL(string: urlString) {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #else
                    UIApplication.shared.open(url)
                    #endif
                }
            } label: {
                Label("Open Source URL", systemImage: "safari")
            }
        }

        Divider()

        Button {
            dataService.togglePin(note)
        } label: {
            Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
        }

        Divider()

        Button(role: .destructive) {
            dataService.deleteNote(note)
        } label: {
            Label("Delete Article", systemImage: "trash")
        }
    }

    // MARK: - Note Menu

    @ViewBuilder
    private var noteMenuItems: some View {
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
}

extension View {
    func noteMenu(note: Note, dataService: DataService, showHighlightsPanel: Binding<Bool>, showAnnotationSidebar: Binding<Bool>) -> some View {
        modifier(NoteMenuModifier(note: note, dataService: dataService, showHighlightsPanel: showHighlightsPanel, showAnnotationSidebar: showAnnotationSidebar))
    }
}

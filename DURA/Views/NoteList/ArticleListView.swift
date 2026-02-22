import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ArticleListView: View {
    @Binding var selectedNote: Note?
    var readingListOnly: Bool = false
    let dataService: DataService

    @Query(filter: #Predicate<Note> { $0.noteKindRaw == "article" }, sort: \Note.modifiedAt, order: .reverse)
    private var allArticles: [Note]

    @State private var searchText = ""
    @State private var sortOrder: NoteSortOrder = .modifiedDescending

    // Import state
    @State private var showFileImporter = false
    @State private var importProgress: Double?
    @State private var importError: ImportError?
    @State private var showImportError = false

    private var filteredArticles: [Note] {
        var articles = allArticles

        if readingListOnly {
            articles = articles.filter { $0.isInReadingList }
        }

        if !searchText.isEmpty {
            articles = articles.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.body.localizedCaseInsensitiveContains(searchText)
            }
        }

        return articles
    }

    var body: some View {
        List(filteredArticles, selection: $selectedNote) { article in
            ArticleRowView(article: article, dataService: dataService)
                .tag(article)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        dataService.deleteNote(article)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        if article.isInReadingList {
                            dataService.removeFromReadingList(article)
                        } else {
                            dataService.addToReadingList(article)
                        }
                    } label: {
                        Label(
                            article.isInReadingList ? "Remove from List" : "Add to List",
                            systemImage: article.isInReadingList ? "bookmark.slash" : "bookmark"
                        )
                    }
                    .tint(.blue)
                }
        }
        .searchable(text: $searchText, prompt: "Search articles...")
        .navigationTitle(readingListOnly ? "Reading List" : "All Articles")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showFileImporter = true } label: {
                    Label("Import File", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
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
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .plainText, .markdown, .rtf, .rtfd, .image, UTType("org.openxmlformats.wordprocessingml.document")!, .mp3, .mpeg4Audio, .wav, UTType("public.aiff-audio")!, UTType("public.aac-audio")!, UTType("public.html")!, UTType(filenameExtension: "epub")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    performImport(url: url)
                }
            case .failure(let error):
                importError = .fileReadFailed(error.localizedDescription)
                showImportError = true
            }
        }
        .overlay(alignment: .bottom) {
            if let progress = importProgress {
                ImportProgressOverlay(progress: progress)
            }
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = importError {
                Text(error.localizedDescription)
            }
        }
        .overlay {
            if filteredArticles.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        readingListOnly ? "Reading List Empty" : "No Articles",
                        systemImage: readingListOnly ? "bookmark" : "doc.richtext",
                        description: Text(readingListOnly ? "Add articles to your reading list." : "Import a file to create an article.")
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        #if os(macOS)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            let supportedExtensions = ["pdf", "txt", "md", "markdown", "rtf", "rtfd", "docx", "png", "jpg", "jpeg", "heic", "tiff", "mp3", "m4a", "wav", "aiff", "aif", "aac", "html", "htm", "epub"]
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else { return false }
            performImport(url: url)
            return true
        }
        #endif
    }

    // MARK: - Import

    private func performImport(url: URL) {
        let service = ImportService(dataService: dataService)

        importProgress = 0

        Task {
            do {
                let note = try await service.importFile(at: url) { value in
                    importProgress = value
                }
                selectedNote = note
                importProgress = nil
            } catch let error as ImportError {
                importProgress = nil
                importError = error
                showImportError = true
            } catch {
                importProgress = nil
                importError = .fileReadFailed(error.localizedDescription)
                showImportError = true
            }
        }
    }
}

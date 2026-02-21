import SwiftUI
import SwiftData

struct BookmarkListView: View {
    let dataService: DataService

    @Query(sort: \Bookmark.addedAt, order: .reverse)
    private var bookmarks: [Bookmark]

    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var searchText = ""
    @State private var filterMode: FilterMode = .all
    @State private var selectedTagFilter: Tag?
    @State private var showingAddSheet = false

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
        case tagged = "Tagged"
    }

    private var filteredBookmarks: [Bookmark] {
        var result = bookmarks

        switch filterMode {
        case .all:
            break
        case .unread:
            result = result.filter { !$0.isRead }
        case .tagged:
            if let tag = selectedTagFilter {
                result = result.filter { bookmark in
                    bookmark.tags?.contains(where: { $0.id == tag.id }) ?? false
                }
            } else {
                result = result.filter { bookmark in
                    !(bookmark.tags?.isEmpty ?? true)
                }
            }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.url.lowercased().contains(query)
            }
        }

        return result
    }

    /// Tags that are actually used by at least one bookmark.
    private var bookmarkTags: [Tag] {
        allTags.filter { tag in
            !(tag.bookmarks?.isEmpty ?? true)
        }
    }

    var body: some View {
        Group {
            if bookmarks.isEmpty {
                ContentUnavailableView(
                    "No Bookmarks",
                    systemImage: "bookmark",
                    description: Text("Save articles and links to read later.")
                )
            } else if filteredBookmarks.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if filteredBookmarks.isEmpty && filterMode == .unread {
                ContentUnavailableView(
                    "All Caught Up",
                    systemImage: "checkmark.circle",
                    description: Text("You've read all your bookmarks.")
                )
            } else if filteredBookmarks.isEmpty && filterMode == .tagged {
                ContentUnavailableView(
                    "No Tagged Bookmarks",
                    systemImage: "tag",
                    description: Text("No bookmarks match the selected tag filter.")
                )
            } else {
                List {
                    ForEach(filteredBookmarks) { bookmark in
                        BookmarkRowView(
                            bookmark: bookmark,
                            dataService: dataService,
                            onToggleRead: { dataService.toggleBookmarkRead(bookmark) },
                            onDelete: { dataService.deleteBookmark(bookmark) }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                dataService.deleteBookmark(bookmark)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                dataService.toggleBookmarkRead(bookmark)
                            } label: {
                                Label(
                                    bookmark.isRead ? "Unread" : "Read",
                                    systemImage: bookmark.isRead ? "circle.fill" : "circle"
                                )
                            }
                            .tint(.blue)

                            Button {
                                openInBrowser(bookmark)
                            } label: {
                                Label("Open", systemImage: "safari")
                            }
                            .tint(.green)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search bookmarks")
        .navigationTitle("Reading List")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Filter", selection: $filterMode) {
                    ForEach(FilterMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if filterMode == .tagged && !bookmarkTags.isEmpty {
                ToolbarItem(placement: .automatic) {
                    Picker("Tag", selection: $selectedTagFilter) {
                        Text("Any Tag").tag(nil as Tag?)
                        ForEach(bookmarkTags) { tag in
                            Text(tag.name).tag(tag as Tag?)
                        }
                    }
                }
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Bookmark", systemImage: "plus")
                }
                .keyboardShortcut("d", modifiers: .command)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddBookmarkSheet(dataService: dataService)
        }
    }

    private func openInBrowser(_ bookmark: Bookmark) {
        guard let url = URL(string: bookmark.url) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }
}

// MARK: - Add Bookmark Sheet

struct AddBookmarkSheet: View {
    let dataService: DataService
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var urlText = ""
    @State private var titleText = ""
    @State private var selectedTags: [Tag] = []
    @State private var showingTagPicker = false
    @State private var newTagName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("URL", text: $urlText)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif

                    TextField("Title (optional)", text: $titleText)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                }

                Section("Tags") {
                    // Selected tag chips
                    if !selectedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(selectedTags) { tag in
                                    HStack(spacing: 2) {
                                        Text("#\(tag.name)")
                                            .font(.caption)
                                        Button {
                                            selectedTags.removeAll { $0.id == tag.id }
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
                        }
                    }

                    Button {
                        showingTagPicker = true
                    } label: {
                        Label("Add Tag", systemImage: "plus")
                            .font(.caption)
                    }
                    .popover(isPresented: $showingTagPicker) {
                        addSheetTagPicker
                    }
                }
            }
            .navigationTitle("Add Bookmark")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBookmark()
                    }
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 250)
        #endif
    }

    private var addSheetTagPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add Tag")
                .font(.headline)
                .padding()

            HStack {
                TextField("New tag...", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addNewTagToSelection()
                    }
                Button("Add") {
                    addNewTagToSelection()
                }
                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)

            List {
                let selectedIDs = Set(selectedTags.map(\.id))
                ForEach(allTags.filter { !selectedIDs.contains($0.id) }) { tag in
                    Button {
                        selectedTags.append(tag)
                    } label: {
                        Label(tag.name, systemImage: "tag")
                    }
                }
            }
            .frame(minWidth: 200, minHeight: 200)
        }
    }

    private func addNewTagToSelection() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let tag = try? dataService.findOrCreateTag(name: name) {
            if !selectedTags.contains(where: { $0.id == tag.id }) {
                selectedTags.append(tag)
            }
        }
        newTagName = ""
    }

    private func saveBookmark() {
        var finalURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalURL.isEmpty else { return }

        // Auto-prefix https:// if no scheme
        if !finalURL.contains("://") {
            finalURL = "https://" + finalURL
        }

        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = selectedTags.isEmpty ? nil : selectedTags
        let bookmark = dataService.createBookmark(url: finalURL, title: title, tags: tags)

        // Fetch metadata in background
        let bookmarkURL = finalURL
        Task {
            await fetchAndApplyMetadata(for: bookmark, urlString: bookmarkURL)
        }

        dismiss()
    }

    @MainActor
    private func fetchAndApplyMetadata(for bookmark: Bookmark, urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        let fetcher = LinkMetadataFetcher()
        let result = await fetcher.fetchMetadata(for: url)

        if bookmark.title.isEmpty, let fetchedTitle = result.title {
            bookmark.title = fetchedTitle
        }
        if let imageData = result.imageData {
            bookmark.thumbnailData = imageData
        }
        try? dataService.save()
    }
}

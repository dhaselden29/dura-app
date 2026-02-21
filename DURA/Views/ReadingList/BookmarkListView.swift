import SwiftUI
import SwiftData

struct BookmarkListView: View {
    let dataService: DataService

    @Query(sort: \Bookmark.addedAt, order: .reverse)
    private var bookmarks: [Bookmark]

    @State private var searchText = ""
    @State private var filterMode: FilterMode = .all
    @State private var showingAddSheet = false

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
    }

    private var filteredBookmarks: [Bookmark] {
        var result = bookmarks

        if filterMode == .unread {
            result = result.filter { !$0.isRead }
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
            } else {
                List {
                    ForEach(filteredBookmarks) { bookmark in
                        BookmarkRowView(
                            bookmark: bookmark,
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

    @State private var urlText = ""
    @State private var titleText = ""

    var body: some View {
        NavigationStack {
            Form {
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
        .frame(minWidth: 400, minHeight: 180)
        #endif
    }

    private func saveBookmark() {
        var finalURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalURL.isEmpty else { return }

        // Auto-prefix https:// if no scheme
        if !finalURL.contains("://") {
            finalURL = "https://" + finalURL
        }

        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        dataService.createBookmark(url: finalURL, title: title)
        dismiss()
    }
}

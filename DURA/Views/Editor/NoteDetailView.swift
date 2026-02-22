import SwiftUI

struct NoteDetailView: View {
    @Bindable var note: Note
    let dataService: DataService

    @State private var lastKnownTitle: String?
    @State private var lastKnownBody: String?
    @State private var bodyFocusRequested = false
    @State private var showHighlightsPanel = false

    @AppStorage("readerTheme") private var themeRaw: String = ReaderDefaults.theme

    private var theme: ReaderTheme {
        ReaderTheme(rawValue: themeRaw) ?? .light
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NoteMetadataBar(note: note, dataService: dataService)

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
                },
                onScrollProgressChanged: { percent in
                    var progress = note.readingProgress
                    guard percent > progress.percentRead else { return }
                    progress.percentRead = percent
                    progress.lastReadDate = Date()
                    if percent >= 85.0 && progress.readAt == nil {
                        progress.readAt = Date()
                    }
                    note.readingProgress = progress
                }
            )

            // Status bar
            statusBar
        }
        .background(theme.swiftUIBackground)
        .onAppear {
            lastKnownTitle = note.title
            lastKnownBody = note.body
            var progress = note.readingProgress
            progress.lastReadDate = Date()
            note.readingProgress = progress
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
        #endif
        .noteMenu(note: note, dataService: dataService, showHighlightsPanel: $showHighlightsPanel)
        .sheet(isPresented: $showHighlightsPanel) {
            HighlightsPanelView(note: note)
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        let statusColor: Color = theme == .light ? .secondary : theme.swiftUITextColor.opacity(0.6)
        let progress = note.readingProgress
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

            if progress.percentRead > 0 {
                Text("\(Int(progress.percentRead))% read")
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            Text("Modified \(note.modifiedAt, style: .relative) ago")
                .font(.caption)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

# DURA — Claude Code Project Guide

Native SwiftUI + SwiftData research note-taking and blog drafting app.

## Build

```bash
xcodegen generate && xcodebuild -scheme DURA_macOS build
xcodebuild -scheme DURA_macOS test   # 215 tests, Swift Testing
```

## Architecture

- **XcodeGen** — `project.yml` is source of truth. Run `xcodegen generate` after adding/removing files.
- **Markdown as source of truth** — `Note.body` is raw markdown. `Block` arrays derived via `BlockParser.parse()`, never persisted.
- **Provider pattern** — Import (9 providers) and Export (3 providers) use `ImportProvider`/`ExportProvider` protocols.
- **JSON-in-SwiftData** — `DraftMetadata`, `ReadingProgress`, highlights stored as `Data` on Note (`draftMetadataData`, `readingProgressData`, `highlightsData`). Enums stored as raw strings (`kanbanStatusRaw`, `sourceRaw`).
- **DataService** — Single CRUD gateway for all models. `@Observable`, not an actor.
- **Cross-platform** — `#if os(macOS)` / `#if os(iOS)`. Platform-specific code in separate files (e.g. `MarkdownTextView_macOS.swift` / `MarkdownTextView_iOS.swift`).
- **Swift 6.0** strict concurrency — `Sendable`, `@MainActor`, `actor` (WordPressService).
- **Tests** — Swift Testing framework (`@Test`, `#expect`, `@Suite`). In-memory ModelContainer.
- **Scroll progress** — `MarkdownTextView` fires `onScrollProgressChanged` callback → `BlockEditorView` passes through → `NoteDetailView` persists to `Note.readingProgress` (high-water mark, debounced 0.3s).
- **Content types** — `NoteKind` enum (`.note` / `.article`). Articles are read-only, rendered via WKWebView. Notes are editable via NSTextView.
- **Article renderer** — `ArticleHTMLRenderer` generates HTML from markdown. `ArticleWebView` (macOS WKWebView) renders it with JS bridge for highlights, scroll progress, selection, and dynamic preference updates. `BlockEditorView` swaps between `ArticleWebView` (read-only) and `MarkdownTextView` (editable).
- **Annotations** — `Highlight` model with `isComment` flag. Context menu on both NSTextView and WKWebView. `AnnotationSidebarView` with click-to-scroll.

## Schema

```
Notebook ◄─ 1:N ─► Note ◄─ N:M ─► Tag ◄─ N:M ─► Bookmark
                     │
                     ├─ 1:N ─► Attachment
                     ├─ 0:1 ─► PodcastClip
                     └─ embedded: DraftMetadata, ReadingProgress, KanbanStatus,
                                 ImportSource, NoteKind, Highlight[]
```

Models registered in `DURAApp.swift`: Note, Notebook, Tag, Attachment, Bookmark, PodcastClip.
Storage: Local SwiftData (no CloudKit). In-memory for tests.

## Project Map

### Models (`DURA/Models/`)
| File | What it defines |
|------|-----------------|
| `Note.swift` | Central `@Model` — title, body, tags, notebook, all JSON-encoded metadata |
| `Notebook.swift` | `@Model` — name, icon, color, parent/child nesting |
| `Tag.swift` | `@Model` — name, color, N:M with Note |
| `Attachment.swift` | `@Model` — binary data, filename, MIME type, OCR text |
| `Bookmark.swift` | `@Model` — URL, title, excerpt, thumbnail, N:M with Tag |
| `PodcastClip.swift` | `@Model` — episode metadata, timestamps, transcript, audio data |
| `Block.swift` | Value type — `BlockType` enum + content, used by parser (not persisted) |
| `DraftMetadata.swift` | `Codable` — WordPress fields (slug, excerpt, categories, status) |
| `ReadingProgress.swift` | `Codable` — percentRead (high-water), readAt (>85%), lastReadDate |
| `KanbanStatus.swift` | Enum — note/idea/drafting/editing/review/published/none |
| `ImportSource.swift` | Enum — manual/web/pdf/docx/markdown/plainText/rtf/image/audio/podcast/… |
| `Highlight.swift` | `Codable` — anchor text, range, color for text highlights |
| `NoteKind.swift` | Enum — `.note` / `.article` content type |
| `ReaderSettings.swift` | Enums — `ReaderTheme` (+ CSS), `ReaderFont` (+ CSS), `ReaderDefaults` |
| `NoteTransferID.swift` | Drag-and-drop transferable wrapper |

### Services (`DURA/Services/`)
| File | What it does |
|------|-------------|
| `DataService.swift` | All CRUD for every model, `@Observable` |
| `ArticleHTMLRenderer.swift` | Markdown + preferences + highlights → full HTML document for WKWebView |
| `BlockParser.swift` | Markdown → `[Block]` parser (and unused `render` reverse) |
| `LinkMetadataFetcher.swift` | Fetches Open Graph metadata for URLs |
| `VoiceRecorderService.swift` | AVAudioRecorder wrapper |
| `SpeechTranscriptionService.swift` | Speech framework transcription |
| `ClipFolderWatcher.swift` | macOS FSEvents folder watcher for podcast clips |

### Services — Import (`DURA/Services/Import/`)
| File | Provider |
|------|----------|
| `ImportService.swift` | Orchestrator — UTType → provider lookup |
| `ImportProvider.swift` | Protocol + `ImportResult` types |
| `MarkdownImportProvider.swift` | `.md` files with front matter |
| `PlainTextImportProvider.swift` | `.txt` files |
| `HTMLImportProvider.swift` | `.html` — includes `HTMLMarkdownConverter` XML parser |
| `RTFImportProvider.swift` | `.rtf` / `.rtfd` |
| `PDFImportProvider.swift` | `.pdf` — PDFKit text extraction |
| `DocxImportProvider.swift` | `.docx` — ZIP + XML parsing |
| `EPUBImportProvider.swift` | `.epub` — ZIP + XHTML parsing |
| `ImageImportProvider.swift` | Images — Vision OCR |
| `AudioImportProvider.swift` | Audio files — speech transcription |

### Services — Export (`DURA/Services/Export/`)
| File | Provider |
|------|----------|
| `ExportService.swift` | Orchestrator — `ExportFormat` enum → provider |
| `ExportProvider.swift` | Protocol + `ExportResult` / `ExportFormat` types |
| `MarkdownExportProvider.swift` | Note → `.md` |
| `HTMLExportProvider.swift` | Note → `.html` (renders each block type) |
| `PDFExportProvider.swift` | Note → `.pdf` via WebKit |

### Services — Podcast (`DURA/Services/Podcast/`)
| File | What it does |
|------|-------------|
| `PodcastClipProcessor.swift` | macOS-only — full pipeline: capture → resolve → extract → transcribe → create note |
| `NowPlayingService.swift` | macOS-only — MediaRemote now-playing info |
| `PodcastResolverService.swift` | iTunes Search API lookup |
| `RSSFeedParser.swift` | RSS XML parser for episode audio URLs |
| `AudioSegmentExporter.swift` | AVFoundation audio segment extraction |

### Services — WordPress (`DURA/Services/WordPress/`)
| File | What it does |
|------|-------------|
| `WordPressService.swift` | `actor` — REST API publish/update |
| `WordPressCredentialStore.swift` | Keychain credential storage |

### Views (`DURA/Views/`)
| File | What it shows |
|------|--------------|
| `ContentView.swift` | Top-level NavigationSplitView (sidebar / list / detail) |
| **Editor/** | |
| `NoteDetailView.swift` | Main editor — title + BlockEditorView + status bar + annotation sidebar |
| `NoteMetadataBar.swift` | Notebook/tag chips, draft badge, WordPress badge |
| `NoteMenuView.swift` | Toolbar menu — pin, favorite, export, publish, kanban, delete |
| `BlockEditorView.swift` | Editor container — swaps ArticleWebView (read-only) / MarkdownTextView (editable) |
| `ArticleWebView.swift` | macOS WKWebView wrapper — rich HTML article rendering, JS bridge |
| `MarkdownTextView_macOS.swift` | NSTextView wrapper — editing, highlights, scroll progress |
| `MarkdownTextView_iOS.swift` | UITextView wrapper — editing, scroll progress |
| `EditorTextView.swift` | NSTextView subclass — keyboard shortcuts, context menu highlights |
| `FormatAction.swift` | `FormatAction` enum shared between platforms |
| `ExportDocument.swift` | `FileDocument` for save panel |
| `ExportProgressOverlay.swift` | Progress bar overlay |
| `HighlightsPanelView.swift` | Sheet listing note highlights |
| `AnnotationSidebarView.swift` | Right sidebar — annotation list with click-to-scroll |
| `AnnotationPopupView.swift` | Sheet for entering annotation text |
| **NoteList/** | |
| `NoteListContentView.swift` | Middle column — search, sort, filter, note list |
| `NoteRowView.swift` | Single note row — title, preview, reading progress |
| `ArticleListView.swift` | Article-specific list view |
| `ArticleRowView.swift` | Article-specific row view |
| `ImportProgressOverlay.swift` | Import progress UI |
| **Sidebar/** | |
| `SidebarView.swift` | Left column — notebooks, tags, smart filters |
| **Kanban/** | |
| `KanbanBoardView.swift` | Draft kanban board |
| `KanbanColumnView.swift` | Single kanban column |
| `KanbanCardView.swift` | Single kanban card |
| **ReadingList/** | |
| `BookmarkListView.swift` | Bookmark list with filters |
| `BookmarkRowView.swift` | Single bookmark row |
| **VoiceRecorder/** | |
| `VoiceRecorderView.swift` | Voice recording UI |
| **PodcastClips/** | |
| `PodcastClipsListView.swift` | Podcast clips list |
| `PodcastClipRowView.swift` | Single podcast clip row |
| **Settings/** | |
| `WordPressSettingsView.swift` | WordPress credentials settings |
| `PodcastClipsSettingsView.swift` | Clip folder path settings |
| `ReaderSettingsView.swift` | Font, theme, spacing settings |

### Tests (`DURATests/`)
| File | What it tests |
|------|--------------|
| `DURATests.swift` | Note, Notebook, Tag, Attachment, Bookmark, Block, KanbanStatus models |
| `ReadingProgressTests.swift` | ReadingProgress model, JSON round-trip, Note integration, business logic |
| `DataServiceTests.swift` | CRUD operations on all models |
| `BlockParserTests.swift` | Markdown → Block parsing |
| `ImportProviderTests.swift` | All 9 import providers |
| `ImportServiceTests.swift` | Import orchestration |
| `DocxImageImportTests.swift` | DOCX image extraction |
| `FrontMatterImportTests.swift` | YAML front matter parsing |
| `ExportProviderTests.swift` | Export providers |
| `ExportServiceTests.swift` | Export orchestration |
| `WordPressServiceTests.swift` | WordPress API mocking |
| `BookmarkListTests.swift` | Bookmark list filtering |
| `ArticleHTMLRendererTests.swift` | ArticleHTMLRenderer: images, highlights, themes, fonts, empty docs |
| `HighlightAnnotationTests.swift` | Highlight and annotation model tests |
| `NoteKindTests.swift` | NoteKind enum and Note.isArticle tests |

## Key Files

| Purpose | File |
|---------|------|
| Central model | `DURA/Models/Note.swift` |
| All CRUD | `DURA/Services/DataService.swift` |
| Markdown parser | `DURA/Services/BlockParser.swift` |
| Article HTML renderer | `DURA/Services/ArticleHTMLRenderer.swift` |
| Import orchestrator | `DURA/Services/Import/ImportService.swift` |
| Export orchestrator | `DURA/Services/Export/ExportService.swift` |
| App structure | `DURA/Views/ContentView.swift` |
| Main editor | `DURA/Views/Editor/NoteDetailView.swift` |
| Article WKWebView | `DURA/Views/Editor/ArticleWebView.swift` |
| Podcast pipeline | `DURA/Services/Podcast/PodcastClipProcessor.swift` |
| Project config | `project.yml` |

## Common Tasks

- **Add import format:** Implement `ImportProvider`, register in `ImportService.init()`
- **Add export format:** Implement `ExportProvider`, add `ExportFormat` case, register in `ExportService.init()`
- **Add block type:** Add `BlockType` case → `BlockParser` → `HTMLExportProvider.renderBlock()`
- **Add SwiftData model:** `@Model` class → schema in `DURAApp.swift` → CRUD in `DataService`
- **Swap MediaRemote for App Store:** Replace `NowPlayingService.getCurrentlyPlaying()` — everything downstream unchanged
- **Editor UI change:** `NoteDetailView.swift` (status bar, layout) or `NoteMenuView.swift` (actions) or `NoteMetadataBar.swift` (chips)
- **Platform-specific editor:** `MarkdownTextView_macOS.swift` or `MarkdownTextView_iOS.swift` (never both unless adding a shared parameter)
- **Article rendering change:** `ArticleHTMLRenderer.swift` (HTML/CSS/JS generation) or `ArticleWebView.swift` (WKWebView wrapper, coordinator, context menu)
- **Add highlight color:** Add case to `HighlightColor` → add `cssColor` value → add `nsColor`/`uiColor` → update `userColors` if user-selectable

## Platform Guards

macOS-only features wrapped in `#if os(macOS)`:
- `ArticleWebView` (WKWebView article renderer)
- `ClipFolderWatcher` (FSEvents)
- `NowPlayingService` + `PodcastClipProcessor` (private MediaRemote API)
- `MediaRemoteBridge.h/.m` excluded from iOS target in `project.yml`
- iOS uses separate `DURA-iOS.entitlements` (sandbox ON)
- iOS falls back to `MarkdownTextView` for read-only articles (no WKWebView renderer yet)

## Known Dead Code (keep for future phases)

- `Note.isBookmark` — never set (Bookmarks are separate model)
- `Note.linkedNoteIDs` — placeholder for Phase 5 wikilinks
- `DraftMetadata.featuredImageId`, `.scheduledDate` — placeholder for Phase 8
- `ImportSource` cases `.onenote`, `.appleNotes`, `.goodnotes`, `.kindle`, `.email` — no providers yet
- `DraftStatus.uploading`, `.scheduled` — not used by WordPress flow
- `BlockParser.render()` — only used in tests

## Status

See `ROADMAP.md` for current state and next phases. See `HISTORY.md` for completed phase details.

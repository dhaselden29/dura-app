# DURA — Roadmap & As-Built Documentation

> **Last updated:** 2026-02-21
> **Codebase:** ~8,000 lines of Swift/Obj-C across 66 source files (+ 11 test files)
> **Tests:** 166 tests in 26 suites (all passing)
> **Platforms:** macOS 15.0+, iOS 18.0+
> **Swift:** 6.0 with strict concurrency
> **Obj-C:** Bridging header for private MediaRemote framework (podcast clips)

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [File Map](#file-map)
4. [Data Model](#data-model)
5. [Feature Inventory](#feature-inventory)
6. [Key Design Decisions](#key-design-decisions)
7. [Known Issues & Technical Debt](#known-issues--technical-debt)
8. [Future Roadmap](#future-roadmap)
9. [Build & Test Instructions](#build--test-instructions)
10. [Session Pickup Guide](#session-pickup-guide)

---

## Project Overview

DURA (Dave's Ultimate Research & Drafting App) is a native SwiftUI + SwiftData app for research note-taking and blog drafting. It features a markdown-first editor, multi-format import/export, a Kanban editorial workflow, and WordPress REST API publishing.

**Git history:**
```
3000112 Add podcast clip capture system (Phase 3.5)
2cacf4c Add Phase 3: audio import/playback, voice recording, speech-to-text, HTML/EPUB import, and expanded file watcher
1282e74 Update roadmap with Phase 3 audio input and import enhancements plan
c3362d6 Add web clipper, clip folder watcher, front matter import, and cleanup
3a1abc4 Add rich text rendering for clipped articles in preview mode
8c7ea69 Add Reading List & Bookmarks UI (Phase 2)
8caf591 Add comprehensive roadmap and as-built documentation
808647c Fix blank PDF export and revert Kanban to inline display
22ba30b Add export system, WordPress sync, import pipeline, and Kanban board
8d1ff93 Initial commit: DURA (Dave's Ultimate Research App)
```

**Remote:** `https://github.com/dhaselden29/dura-app.git` (branch: `main`)

---

## Architecture

### Layers

```
┌──────────────────────────────────────────────────┐
│  Views (SwiftUI)                                 │
│  ContentView → SidebarView                       │
│             → NoteListContentView                │
│             → NoteDetailView                     │
│             → KanbanBoardView                    │
│             → PodcastClipsListView               │
│             → BookmarkListView                   │
│             → Settings (General, WP, Podcasts)   │
├──────────────────────────────────────────────────┤
│  Services                                        │
│  DataService (SwiftData CRUD)                    │
│  BlockParser (Markdown ↔ Blocks)                 │
│  ImportService + 9 ImportProviders               │
│  ExportService + 3 ExportProviders               │
│  PodcastClipProcessor + NowPlayingService        │
│  PodcastResolverService + RSSFeedParser           │
│  AudioSegmentExporter                            │
│  SpeechTranscriptionService + VoiceRecorderService│
│  WordPressService (REST API)                     │
│  WordPressCredentialStore (Keychain)              │
│  ClipFolderWatcher (FSEvents)                    │
├──────────────────────────────────────────────────┤
│  Models (SwiftData @Model + value types)         │
│  Note, Notebook, Tag, Attachment, Bookmark       │
│  PodcastClip, Block, DraftMetadata, KanbanStatus │
├──────────────────────────────────────────────────┤
│  Persistence: SwiftData (local, no CloudKit)     │
└──────────────────────────────────────────────────┘
```

### Key Patterns

- **Markdown as source of truth** — `Note.body` is always markdown. `Block` arrays are derived via `BlockParser.parse()` and never persisted.
- **Provider pattern** — Import and export use protocol-based providers (`ImportProvider`, `ExportProvider`) registered in service lookup tables. Add a new format by implementing the protocol and registering.
- **JSON-in-SwiftData** — `DraftMetadata` is a `Codable` struct stored as `Data` in `Note.draftMetadataData`, decoded on demand via computed property. Same pattern for `kanbanStatusRaw`/`sourceRaw` using raw string encoding.
- **Strict concurrency** — Swift 6.0 with `Sendable`, `@MainActor`, `actor` (WordPressService). Progress callbacks are `@Sendable`.
- **Cross-platform** — `#if canImport(AppKit)` / `#if canImport(UIKit)` for platform-specific code (text views, PDF generation). Shared everything else.
- **Obj-C bridge for private APIs** — `MediaRemoteBridge.h/.m` uses `dlopen`/`dlsym` to access the private MediaRemote framework. Isolated behind `NowPlayingService` as a single swap point for App Store compliance.

### Project Generator

Uses **XcodeGen** (`project.yml`). Run `xcodegen generate` after adding/removing files. Targets:
- `DURA_macOS` / `DURA_iOS` (app targets)
- `DURATests_macOS` / `DURATests_iOS` (test bundles)

---

## File Map

### Models (`DURA/Models/`)

| File | Types | Purpose |
|------|-------|---------|
| `Note.swift` | `Note` (@Model) | Core entity. Title, body (markdown), relationships to Notebook/Tags/Attachments, computed properties for kanbanStatus, source, draftMetadata, isDraft |
| `Notebook.swift` | `Notebook` (@Model) | Hierarchical folders. Self-referential parent-child. Cascade deletes children, nullifies notes |
| `Tag.swift` | `Tag` (@Model) | Labels for notes and bookmarks. Many-to-many |
| `Block.swift` | `BlockType` (enum), `Block` (struct) | 12 block types with metadata. Value type, never persisted directly |
| `Attachment.swift` | `Attachment` (@Model) | File storage with `.externalStorage` for data. OCR text field |
| `Bookmark.swift` | `Bookmark` (@Model) | Reading list items. URL, title, excerpt, read status |
| `DraftMetadata.swift` | `DraftStatus` (enum), `DraftMetadata` (struct) | WordPress fields: postId, status, slug, excerpt, categories, tags, dates |
| `ImportSource.swift` | `ImportSource` (enum) | 14 source types (manual, markdown, pdf, docx, image, web, podcast, etc.) |
| `PodcastClip.swift` | `PodcastClip` (@Model), `ClipProcessingStatus` (enum) | Podcast clip capture with processing pipeline status |
| `KanbanStatus.swift` | `KanbanStatus` (enum) | 7 statuses: none, note, idea, researching, drafting, review, published. `boardStatuses` excludes `.none` |
| `NoteTransferID.swift` | `NoteTransferID` | Lightweight Transferable for Kanban drag-and-drop |

### Services (`DURA/Services/`)

| File | Types | Purpose |
|------|-------|---------|
| `DataService.swift` | `DataService` (@Observable) | Central CRUD for all SwiftData models (Notes, Notebooks, Tags, Attachments, Bookmarks, PodcastClips). ~35 methods. Sorting, filtering, search |
| `BlockParser.swift` | `BlockParser` (struct) | Static `parse(_:)` and `render(_:)`. Line-by-line markdown parsing, handles all 12 block types |
| `SpeechTranscriptionService.swift` | `SpeechTranscriptionService` (Sendable) | On-device `SFSpeechRecognizer` transcription with progress callbacks |
| `VoiceRecorderService.swift` | `VoiceRecorderService` | `AVAudioRecorder`-based voice note capture (M4A) |

### Import (`DURA/Services/Import/`)

| File | Types | Purpose |
|------|-------|---------|
| `ImportProvider.swift` | `ImportProvider` (protocol), `ImportResult`, `ImportError` | Shared types. UTType `.markdown` extension |
| `ImportService.swift` | `ImportService` (@MainActor) | Orchestrator. Resolves provider by UTType, creates Note + Attachment |
| `MarkdownImportProvider.swift` | `MarkdownImportProvider` | Title from H1 or filename. Preserves raw markdown |
| `PlainTextImportProvider.swift` | `PlainTextImportProvider` | First non-empty line as title (max 100 chars) |
| `RTFImportProvider.swift` | `RTFImportProvider` | NSAttributedString parsing. Supports .rtf and .rtfd |
| `PDFImportProvider.swift` | `PDFImportProvider` | Text layer extraction + Vision OCR fallback. Multi-page |
| `DocxImportProvider.swift` | `DocxImportProvider` | NSAttributedString with OOXML document type |
| `ImageImportProvider.swift` | `ImageImportProvider` | Vision OCR. PNG, JPEG, HEIC, TIFF, BMP, GIF |
| `AudioImportProvider.swift` | `AudioImportProvider` | Audio file import. MP3, M4A, WAV, AIFF, AAC |
| `HTMLImportProvider.swift` | `HTMLImportProvider` | HTML content extraction and markdown conversion |
| `EPUBImportProvider.swift` | `EPUBImportProvider` | EPUB parsing (zipped XHTML), chapter extraction |

### Podcast (`DURA/Services/Podcast/`)

| File | Types | Purpose |
|------|-------|---------|
| `MediaRemoteBridge.h/.m` | `MediaRemoteBridge` (Obj-C) | Private MediaRemote framework bridge via dlopen/dlsym |
| `DURA-Bridging-Header.h` | — | Swift↔Obj-C bridging header |
| `NowPlayingService.swift` | `NowPlayingInfo`, `NowPlayingService` | Reads system now-playing info (swap point for App Store) |
| `PodcastResolverService.swift` | `PodcastResolverService` | iTunes Search API + RSS feed episode resolution |
| `RSSFeedParser.swift` | `RSSEpisode`, `RSSFeedParser` | XMLParserDelegate-based RSS feed parser |
| `AudioSegmentExporter.swift` | `AudioSegmentExporter` | AVFoundation audio segment extraction |
| `PodcastClipProcessor.swift` | `PodcastClipProcessor` (@MainActor @Observable) | Full pipeline orchestrator: capture → resolve → extract → transcribe → note |

### Clip Watcher (`DURA/Services/`)

| File | Types | Purpose |
|------|-------|---------|
| `ClipFolderWatcher.swift` | `ClipFolderWatcher` (@Observable) | FSEvents watcher on `~/Downloads/DURA-Clips/`. Auto-imports `.md` files, moves to `.imported/` subfolder |

### Web Clipper (`dura-clipper/`)

| File | Purpose |
|------|---------|
| `manifest.json` | Chrome Manifest V3. Permissions: activeTab, contextMenus, storage, downloads, scripting |
| `background.js` | Service worker. Context menus (clip page/selection/link/image). YAML front matter + markdown assembly |
| `content.js` | Content script. Readability.js extraction. Full/selection/bookmark modes. OG/Twitter metadata |
| `popup.html/js/css` | Popup UI. Turndown HTML→Markdown conversion with GFM plugin |
| `options.html/js/css` | Settings: subfolder path, notebook list, default mode, auto-close, tag history |
| `lib/` | Bundled readability.js and Turndown library |

### Export (`DURA/Services/Export/`)

| File | Types | Purpose |
|------|-------|---------|
| `ExportProvider.swift` | `ExportProvider` (protocol), `ExportFormat`, `ExportResult`, `ExportError`, `sanitizeFilename()` | Shared types |
| `ExportService.swift` | `ExportService` (Sendable) | Provider registry. Routes by ExportFormat |
| `MarkdownExportProvider.swift` | `MarkdownExportProvider` | Prepends `# title` if missing. UTF-8 |
| `HTMLExportProvider.swift` | `HTMLExportProvider` | BlockParser → HTML blocks. Inline markdown conversion. Responsive CSS. `renderHTML()` reused by WordPress |
| `PDFExportProvider.swift` | `PDFExportProvider` | WKWebView.pdf() cross-platform. US Letter, 50pt margins. Faithful HTML/CSS rendering |

### WordPress (`DURA/Services/WordPress/`)

| File | Types | Purpose |
|------|-------|---------|
| `WordPressService.swift` | `WordPressConfig`, `WordPressError`, `WordPressService` (actor) | REST API client. POST/PUT `/wp/v2/posts`. Basic Auth. Accepts URLSession for test injection |
| `WordPressCredentialStore.swift` | `WordPressCredentialStore`, `KeychainError` | Keychain CRUD. Service: `com.dura.wordpress` |

### Views (`DURA/Views/`)

| File | Types | Purpose |
|------|-------|---------|
| `ContentView.swift` | `ContentView`, `SidebarItem`, `SettingsView`, `GeneralSettingsView` | Root 3-column NavigationSplitView. macOS Settings with General + WordPress + Podcasts tabs |
| **Sidebar/** | | |
| `SidebarView.swift` | `SidebarView` | Library, Notebooks (hierarchical), Tags, Workflow sections. Add notebook inline |
| **NoteList/** | | |
| `NoteListContentView.swift` | `NoteListContentView` | List with search, sort, swipe actions. Import button + drag-and-drop. Cmd+N new note |
| `NoteRowView.swift` | `NoteRowView` | Pin/star icons, title, preview, metadata chips, context menu |
| `ImportProgressOverlay.swift` | `ImportProgressOverlay` | Capsule with progress bar |
| **Editor/** | | |
| `NoteDetailView.swift` | `NoteDetailView` | Full editor. Metadata bar, title, BlockEditorView, status bar. Export/publish menus and flows |
| `BlockEditorView.swift` | `BlockEditorView` | Segmented "Markdown / Rich Text" picker. Edit mode (MarkdownTextView) + preview mode (block render with rich text). Formatting toolbar |
| `BlockViews.swift` | 14 view types | Renderers for each BlockType. Rich markdown in preview, drag handle hidden in preview |
| `MarkdownText.swift` | `MarkdownText`, `IsBlockPreviewKey` | Inline markdown renderer via `AttributedString(markdown:)`. Environment key for preview mode |
| `MarkdownTextView.swift` | `MarkdownTextView` | Platform-specific (NSViewRepresentable / UIViewRepresentable). Keyboard shortcuts for formatting |
| `ExportDocument.swift` | `ExportDocument` (FileDocument) | Wrapper for `.fileExporter()` |
| `ExportProgressOverlay.swift` | `ExportProgressOverlay` | Capsule with customizable label |
| **Kanban/** | | |
| `KanbanBoardView.swift` | `KanbanBoardView` | Horizontal scrolling columns. Drag-and-drop cards |
| `KanbanColumnView.swift` | `KanbanColumnView` | Collapsible column with header, count badge, drop zone |
| `KanbanCardView.swift` | `KanbanCardView` | Compact card. Selection/connection highlighting. Context menu |
| **ReadingList/** | | |
| `BookmarkListView.swift` | `BookmarkListView`, `AddBookmarkSheet` | Bookmark list with search, filter (all/unread), add sheet, swipe actions |
| `BookmarkRowView.swift` | `BookmarkRowView` | Bookmark row with URL, title, read status |
| **PodcastClips/** | | |
| `PodcastClipsListView.swift` | `PodcastClipsListView` | Filterable list of podcast clips. Search, status filter, swipe delete |
| `PodcastClipRowView.swift` | `PodcastClipRowView` | Row with artwork, title, timestamp, status badge |
| **VoiceRecorder/** | | |
| `VoiceRecorderView.swift` | `VoiceRecorderView` | Voice recording UI with record/stop, creates note with audio block |
| **Settings/** | | |
| `WordPressSettingsView.swift` | `WordPressSettingsView` | Site URL, username, app password. Test/Save/Clear. Keychain backed |
| `PodcastClipsSettingsView.swift` | `PodcastClipsSettingsView` | Enable toggle, clip duration picker, shortcut display |

### Tests (`DURATests/`)

| File | Framework | Coverage |
|------|-----------|----------|
| `DURATests.swift` | Swift Testing | Note, KanbanStatus, Block, Notebook, Tag, Attachment, Bookmark, NoteSortOrder models |
| `BlockParserTests.swift` | Swift Testing | All block types parse + render + round-trip (43 tests) |
| `DataServiceTests.swift` | Swift Testing | CRUD, relationships, draft lifecycle, search, filtering (26 tests) |
| `ImportServiceTests.swift` | Swift Testing | Markdown/PlainText import, notebook routing, error handling (5 tests) |
| `ImportProviderTests.swift` | Swift Testing | Per-provider tests: Markdown, PlainText, RTF, PDF, filenameStem |
| `DocxImageImportTests.swift` | Swift Testing | DOCX + Image provider tests |
| `ExportProviderTests.swift` | Swift Testing | Markdown (title prepending, dedup), HTML (all block types, escaping, inline), sanitizeFilename |
| `ExportServiceTests.swift` | Swift Testing | Provider routing, MIME types, PDF generation, empty content |
| `WordPressServiceTests.swift` | Swift Testing | MockURLProtocol. Create/update posts, draft flag, auth header, connection test, 401 handling |
| `BookmarkListTests.swift` | Swift Testing | Bookmark list view and filtering tests |
| `FrontMatterImportTests.swift` | Swift Testing | YAML front matter parsing: title, url, tags, notebook, source |

### Configuration

| File | Purpose |
|------|---------|
| `project.yml` | XcodeGen project definition. Dual-platform targets + test bundles |
| `DURA/Info.plist` | Bundle config. Dark appearance. Custom UTType `com.dura.note-transfer-id` |
| `DURA/DURA.entitlements` | Sandbox OFF. Network client ON. User file read-write ON |

---

## Data Model

### Entity Relationship Diagram

```
Notebook ◄──── 1:N ────► Note ◄──── N:M ────► Tag
   │                       │                     │
   └─ parent/child (self)  ├─ 1:N ─► Attachment  └─ N:M ─► Bookmark
                           │
                           ├─ 0:1 ─► PodcastClip
                           │
                           └─ embedded: DraftMetadata (JSON)
                              embedded: KanbanStatus (raw string)
                              embedded: ImportSource (raw string)
                              derived:  [Block] (via BlockParser)
```

### SwiftData Schema

Models registered in `DURAApp.swift`:
```swift
Schema([Note.self, Notebook.self, Tag.self, Attachment.self, Bookmark.self, PodcastClip.self])
```

Storage: Local only (`cloudKitDatabase: .none`). In-memory for tests.

---

## Feature Inventory

### Implemented & Working

| Feature | Status | Notes |
|---------|--------|-------|
| Note CRUD | Done | Create, read, update, delete with auto-save |
| Markdown editor | Done | Native text view with Cmd+B/I/E shortcuts, preview toggle |
| Block parser | Done | 12 block types, bidirectional, well-tested |
| Hierarchical notebooks | Done | Parent-child nesting, sidebar tree |
| Tags | Done | Many-to-many, inline create, visual chips |
| Pin / Favorite | Done | Pinned notes sort to top |
| Search | Done | Title + body full-text |
| Sort options | Done | 6 sort orders |
| Import (9 formats) | Done | MD, TXT, RTF, PDF, DOCX, Images (OCR), Audio, HTML, EPUB |
| Drag-and-drop import | Done | macOS file drop on note list |
| Export: Markdown | Done | Title prepending, sanitized filenames |
| Export: HTML | Done | Full CSS, responsive, all block types |
| Export: PDF | Done | CTFramesetter multi-page (macOS), UIPrintPageRenderer (iOS) |
| WordPress publish | Done | Create + update posts, Basic Auth, Keychain credentials |
| WordPress settings | Done | Test connection, save/clear credentials |
| Kanban board | Done | Inline display, drag-and-drop, collapsible columns, card highlighting |
| Draft workflow | Done | Promote/demote, kanban status, WP status badge |
| Bookmarks model | Done | Full model with read/unread, tags, thumbnails |
| Attachments | Done | External storage, OCR text, MIME type tracking |
| Web clipper (Chrome) | Done | dura-clipper extension: Readability + Turndown, YAML front matter, context menus |
| Clip folder watcher | Done | FSEvents-based auto-import of `.md` files from `~/Downloads/DURA-Clips/` |
| Front matter import | Done | YAML front matter parsing: title, url, tags, notebook, excerpt, featured_image, source |
| Rich text preview | Done | MarkdownText view renders inline markdown (bold, italic, links, code, strikethrough) in Rich Text mode |
| Audio import + playback | Done | AudioImportProvider, AVPlayer in AudioBlockView, drag-and-drop audio files |
| Voice recording | Done | VoiceRecorderView with AVAudioRecorder, creates note with audio block |
| Speech-to-text | Done | On-device SFSpeechRecognizer transcription with progress |
| HTML import | Done | HTMLImportProvider with content extraction and markdown conversion |
| EPUB import | Done | EPUBImportProvider with chapter extraction and XHTML→Markdown |
| Podcast clips | Done | Capture now-playing → resolve metadata → extract audio → transcribe → linked note. Private MediaRemote API (personal use only) |

### Partially Implemented

| Feature | Status | What's Missing |
|---------|--------|----------------|
| Reading List UI | Partial | BookmarkListView with search/filter/add/swipe. Missing: link preview thumbnails, tag from UI |
| Wikilinks | Model only | `linkedNoteIDs` field exists. No parsing, no UI, no bidirectional resolution |
| Block-level editing | Preview only | Blocks render read-only. Editing is raw markdown only |
| WP categories/tags picker | Metadata only | DraftMetadata has fields. No selection UI in editor |
| WP scheduled publishing | Metadata only | `scheduledDate` field exists. No date picker UI |
| WP featured image | Metadata only | `featuredImageId` field exists. No picker or upload |
| CloudKit sync | Placeholder | Comment in DURAApp.swift. Config set to `.none` |

---

## Key Design Decisions

### 1. Markdown as Source of Truth
**Decision:** Store `Note.body` as raw markdown, never as blocks or HTML.
**Rationale:** Markdown is portable, human-readable, and widely supported. Blocks are ephemeral views derived on demand. This avoids migration issues and dual-source-of-truth bugs.

### 2. SwiftData over Core Data
**Decision:** Use SwiftData with `@Model` macros.
**Rationale:** Modern Swift-native API, better concurrency support, simpler relationship management. Trade-off: fewer migration tools, less community knowledge.

### 3. Provider Pattern for Import/Export
**Decision:** Protocol-based providers registered in service lookup tables.
**Rationale:** Adding a new format requires only implementing the protocol and registering. No changes to service logic. Mirrors each other (ImportProvider/ExportProvider).

### 4. CTFramesetter for PDF (macOS)
**Decision:** Replaced `NSLayoutManager` approach with Core Text `CTFramesetter`.
**Rationale:** `NSLayoutManager` produced blank PDFs because glyph layout wasn't triggering properly in a CGContext. CTFramesetter handles frame-based text layout natively in Core Graphics.

### 5. Kanban Inline (not Separate Window)
**Decision:** Reverted from `Window("Kanban Board", id: "kanban")` to inline display.
**Rationale:** Separate window approach caused UX issues. Inline in the NavigationSplitView content column works better with the app's navigation model.

### 6. Actor for WordPressService
**Decision:** `actor WordPressService` instead of class.
**Rationale:** Thread-safe networking without manual synchronization. URLSession injection via init for testability.

### 7. Keychain for WordPress Credentials
**Decision:** Security framework with `SecItemAdd`/`SecItemCopyMatching`.
**Rationale:** App passwords should not be stored in UserDefaults or SwiftData. Keychain provides OS-level encryption.

### 8. App Sandbox Disabled
**Decision:** Sandbox OFF in entitlements.
**Rationale:** Needed for unrestricted file system access (import/export). Network client entitlement for WordPress API.

### 9. Private MediaRemote Framework for Podcast Clips
**Decision:** Use `dlopen`/`dlsym` via Obj-C bridge to access `MRMediaRemoteGetNowPlayingInfo` from the private MediaRemote framework.
**Rationale:** `MPNowPlayingInfoCenter.default().nowPlayingInfo` only returns what YOUR app published — it cannot read other apps. The private API is the only way to get real-time playback position from Apple Podcasts. Isolated behind `NowPlayingService` as a single swap point. For personal use; App Store submission requires replacing with manual-entry UI or share-link parsing.

### 10. Pipeline Processor Pattern for Podcast Clips
**Decision:** `PodcastClipProcessor` orchestrates a multi-step async pipeline (capture → resolve → extract → transcribe → note) with non-fatal failure at each step.
**Rationale:** Each step can fail independently without blocking the others. A clip without transcription is still useful. A clip without audio resolution still captures the moment. Status tracking (pending/resolved/failed) lets the UI reflect progress.

---

## Known Issues & Technical Debt

### Bugs to Fix

1. ~~**PDF export typography**~~ — ✅ Fixed: Replaced CTFramesetter with `WKWebView.pdf()` for faithful HTML/CSS rendering.

2. ~~**NoteListViewModel partially unused**~~ — ✅ Fixed: Deleted. `NoteListContentView` does its own filtering inline.

3. ~~**Export test files in repo**~~ — ✅ Fixed: Deleted and gitignored.

### Technical Debt

4. ~~**No `.gitignore`**~~ — ✅ Fixed: Added with standard exclusions + `TestFiles/Export*`.

5. ~~**KanbanWindowView orphaned**~~ — ✅ Fixed: Deleted.

6. **Bookmark UI partial** — `Bookmark` model is fully implemented, Reading List sidebar item wired, but limited functionality (no add action, no link previews).

7. **Wikilink infrastructure unused** — `Note.linkedNoteIDs` field is declared but never written to or read from in any view or service.

8. ~~**Mixed test frameworks**~~ — ✅ Fixed: All tests now use Swift Testing.

9. **No error handling on DataService.save()** — Several call sites use `try? dataService.save()` silently swallowing errors.

10. ~~**WordPress publish progress**~~ — ✅ Fixed: Wired real progress callback from `WordPressService.publishPost()`.

11. **WordPress.com not supported** — Current implementation uses self-hosted WP REST API with Basic Auth (Application Passwords). WordPress.com sites require OAuth2 via `public-api.wordpress.com`. See Phase 5 roadmap.

12. **Podcast clips use private API** — `MediaRemoteBridge.m` uses `dlopen` on the private MediaRemote framework. Works for personal use but WILL be rejected by App Store review. See App Store warning in Phase 3.5 roadmap section for swap instructions.

---

## Future Roadmap

### Phase 1: Polish & Stability ✅
- [x] Add `.gitignore` (with `TestFiles/Export*` pattern)
- [x] Delete orphaned `KanbanWindowView.swift`
- [x] Delete unused `NoteListViewModel.swift`
- [x] Wire real progress tracking to WordPress publish (progress callback)
- [x] Rewrite PDF export with `WKWebView.pdf()` for faithful HTML/CSS rendering
- [x] Migrate `DataServiceTests` and `ImportServiceTests` from XCTest → Swift Testing
- [x] Delete untracked export test artifacts

### Phase 2: Reading List & Bookmarks
- [x] Reading List UI (sidebar wired, bookmark list view)
- [ ] Add Bookmark action (URL input or share sheet)
- [ ] Link preview thumbnails
- [ ] Tag bookmarks from UI
- [ ] Open bookmark in browser

### Phase 3: Audio Input & Import Enhancements ✅
> **Status:** Completed.

#### 3a. Audio File Import + Playback
- [x] Create `AudioImportProvider` — support MP3, M4A, WAV, AIFF, AAC via UTTypes
- [x] Wire `AVPlayer` playback into existing `AudioBlockView` stub (play/pause/seek)
- [x] Store audio files as `Attachment` with `.externalStorage`
- [x] Add `ImportSource.audio` case to `ImportSource` enum
- [x] Register audio UTTypes in `ImportService` provider lookup
- [x] Enable drag-and-drop of audio files onto note list

#### 3b. Voice Note Recording
- [x] Add microphone permission (`NSMicrophoneUsageDescription` in Info.plist)
- [x] Create `VoiceRecorderView` — record button, waveform visualization, stop/save
- [x] Use `AVAudioRecorder` to capture M4A audio
- [x] On save: create new note with audio block + attachment
- [x] Add recording entry point in toolbar or note list

#### 3c. On-Device Speech-to-Text Transcription
- [x] Integrate `SFSpeechRecognizer` for on-device transcription (macOS 15+ / iOS 18+)
- [x] Add `Speech` framework and `NSSpeechRecognitionUsageDescription` permission
- [x] Post-recording transcription: audio → text inserted as note body below audio block
- [x] Progress indicator during transcription
- [x] Fallback handling when on-device recognition unavailable

#### 3d. Expand ClipFolderWatcher
- [x] Watch all supported import types (PDF, DOCX, RTF, TXT, images, audio) not just `.md`
- [x] Configure watched extensions in settings
- [x] Show watcher status and recent imports in UI

#### 3e. HTML Import
- [x] Create `HTMLImportProvider` — support `.html` and `.htm` files
- [x] Extract main content (strip nav, footer, scripts) or use full body
- [x] Convert HTML → Markdown (similar to dura-clipper's Turndown approach, server-side)
- [x] Register `.html` UTType in `ImportService`

#### 3f. EPUB Import
- [x] Create `EPUBImportProvider` — parse EPUB (zipped XHTML)
- [x] Extract text content and inline images from EPUB chapters
- [x] Convert XHTML → Markdown, concatenate chapters with `## Chapter` headings
- [x] Register `UTType(filenameExtension: "epub")` in `ImportService`

### Phase 3.5: Podcast Clips ← CURRENT
> **Status:** Implemented. Captures now-playing info from Apple Podcasts (or any audio app),
> resolves episode metadata via iTunes Search + RSS, extracts audio segments, and transcribes
> into linked notes.

> ⚠️ **APP STORE WARNING — Private API Usage**
>
> `NowPlayingService` uses the private `MediaRemote` framework via
> `DURA/Services/Podcast/MediaRemoteBridge.m` to read other apps' now-playing
> state. This WILL be rejected by App Store review.
>
> **To make App Store compatible:**
> 1. Replace `MediaRemoteBridge.h/.m` with a manual-entry UI or share-link parser
> 2. Update `NowPlayingService.getCurrentlyPlaying()` to use the new input method
> 3. Remove bridging header reference from `project.yml`
> 4. Everything downstream (PodcastClip model, processor, UI) stays unchanged

#### Features
- [x] `PodcastClip` SwiftData model with processing status pipeline
- [x] MediaRemote bridge (Obj-C) for reading system now-playing info
- [x] `NowPlayingService` — Swift wrapper (single swap point for App Store)
- [x] `PodcastResolverService` — iTunes Search API + RSS feed resolution
- [x] `RSSFeedParser` — XMLParser-based RSS episode extraction
- [x] `AudioSegmentExporter` — AVFoundation segment extraction (position ± duration/2)
- [x] `PodcastClipProcessor` — full pipeline: capture → resolve → extract → transcribe → note
- [x] `PodcastClipsListView` — filterable list (All/Pending/Resolved/Failed)
- [x] `PodcastClipRowView` — artwork, title, timestamp, status badge
- [x] `PodcastClipsSettingsView` — enable toggle, clip duration, shortcut display
- [x] Sidebar integration in Workflow section
- [x] Keyboard shortcut: ⌘⇧P to capture clip
- [x] `ImportSource.podcast` case added
- [x] `Note.podcastClip` relationship

#### New Files (12)
| File | Purpose |
|------|---------|
| `DURA/Models/PodcastClip.swift` | SwiftData model + `ClipProcessingStatus` enum |
| `DURA/Services/Podcast/MediaRemoteBridge.h` | Obj-C header for private MediaRemote API |
| `DURA/Services/Podcast/MediaRemoteBridge.m` | Obj-C implementation — dlopen/dlsym |
| `DURA/Services/Podcast/DURA-Bridging-Header.h` | Swift↔Obj-C bridging header |
| `DURA/Services/Podcast/NowPlayingService.swift` | Swift async wrapper around MediaRemoteBridge |
| `DURA/Services/Podcast/PodcastResolverService.swift` | iTunes Search + RSS resolution |
| `DURA/Services/Podcast/RSSFeedParser.swift` | XMLParserDelegate RSS feed parser |
| `DURA/Services/Podcast/AudioSegmentExporter.swift` | AVFoundation audio segment extraction |
| `DURA/Services/Podcast/PodcastClipProcessor.swift` | Pipeline orchestrator |
| `DURA/Views/PodcastClips/PodcastClipsListView.swift` | Podcast clips list view |
| `DURA/Views/PodcastClips/PodcastClipRowView.swift` | Podcast clip row view |
| `DURA/Views/Settings/PodcastClipsSettingsView.swift` | Podcast settings tab |

#### Modified Files (10)
| File | Change |
|------|--------|
| `DURA/Models/Note.swift` | Added `podcastClip: PodcastClip?` relationship |
| `DURA/Models/ImportSource.swift` | Added `.podcast` case |
| `DURA/App/DURAApp.swift` | Added `PodcastClip.self` to schema |
| `DURA/Services/DataService.swift` | Added PodcastClip CRUD methods |
| `DURA/Views/ContentView.swift` | Added `.podcastClips` sidebar item, routing, settings tab, ⌘⇧P shortcut |
| `DURA/Views/Sidebar/SidebarView.swift` | Added Podcast Clips to Workflow section |
| `DURA/Views/NoteList/NoteListContentView.swift` | Handle `.podcastClips` in sidebar filter |
| `DURA/Resources/Preview Content/PreviewSampleData.swift` | Sample PodcastClip instances |
| `project.yml` | Bridging header path for both targets |
| `ROADMAP.md` | Phase 3 completed, Phase 3.5 documented |

### Phase 4: Wikilinks & Note Graph
- [ ] Parse `[[note title]]` syntax in markdown
- [ ] Resolve wikilinks to note IDs bidirectionally
- [ ] Backlinks panel in NoteDetailView
- [ ] Note graph visualization

### Phase 5: WordPress Enhancements
- [ ] **WordPress.com OAuth2 support** — Register app at `developer.wordpress.com/apps/` (free), implement OAuth2 token flow, hit `public-api.wordpress.com/rest/v1.1/` instead of `/wp-json/wp/v2/`. Currently only self-hosted WP with Application Passwords works; WordPress.com (free/paid) uses a different API entirely.
- [ ] Category and tag picker UI for WP publishing
- [ ] Featured image picker + upload to WP media library
- [ ] Scheduled publish date picker
- [ ] Pull existing posts from WP for editing

### Phase 6: CloudKit Sync
- [ ] Enable CloudKit in ModelConfiguration
- [ ] Configure signing and entitlements
- [ ] Handle merge conflicts
- [ ] Sync status indicators

### Phase 7: Block Editor
- [ ] Editable block-level UI (not just raw markdown)
- [ ] Drag-and-drop block reordering
- [ ] Slash commands for block insertion
- [ ] Inline image upload and embedding

### Phase 8: Advanced Features
- [ ] AI-assisted research summaries
- [ ] Web clipper (Safari extension)
- [ ] Collaboration / sharing
- [ ] Custom themes and typography
- [ ] Keyboard navigation improvements

---

## Build & Test Instructions

### Prerequisites
- Xcode 16.0+
- XcodeGen (`brew install xcodegen`)
- macOS 15.0+ (for macOS target)

### Build
```bash
cd "Ultimate Research & Drafting App"
xcodegen generate
xcodebuild -scheme DURA_macOS -destination 'platform=macOS' build
```

### Test
```bash
xcodebuild -scheme DURA_macOS -destination 'platform=macOS' test
```

### Run
```bash
open ~/Library/Developer/Xcode/DerivedData/DURA-*/Build/Products/Debug/DURA.app
```

Or build and run from Xcode directly.

---

## Session Pickup Guide

**When starting a new Claude Code session on this project, here's what you need to know:**

### Quick Orientation
1. **project.yml** is the source of truth for project structure (XcodeGen)
2. **Note.body** is always markdown — blocks are derived, never stored
3. **Import/Export** follow identical provider patterns — check `ImportProvider.swift` and `ExportProvider.swift` for the protocols
4. **DraftMetadata** is JSON embedded in Note — presence = isDraft
5. **DataService** is the single CRUD gateway for all SwiftData operations (Notes, Notebooks, Tags, Attachments, Bookmarks, PodcastClips)
6. **Tests use Swift Testing** — `@Test`, `#expect`, `@Suite`, `Issue.record()`
7. **ClipFolderWatcher** auto-imports `.md` files from `~/Downloads/DURA-Clips/` via FSEvents
8. **dura-clipper/** is a Chrome extension that clips web pages to markdown with YAML front matter
9. **MarkdownImportProvider** parses YAML front matter for metadata (title, url, tags, notebook, source)
10. **Rich text preview** uses `MarkdownText` view + `isBlockPreview` environment key
11. **PodcastClipProcessor** orchestrates capture → resolve → extract → transcribe → note pipeline
12. **NowPlayingService** is the single swap point for the private MediaRemote API (App Store compliance)
13. **Obj-C bridging header** at `DURA/Services/Podcast/DURA-Bridging-Header.h` — set in `project.yml` for both targets

### Key Files to Read First
1. `DURA/Models/Note.swift` — central entity, all relationships (including `podcastClip`)
2. `DURA/Services/DataService.swift` — all CRUD methods (Notes, Notebooks, Tags, Attachments, Bookmarks, PodcastClips)
3. `DURA/Services/BlockParser.swift` — markdown ↔ blocks
4. `DURA/Services/Import/ImportService.swift` — import orchestrator with 9 provider types
5. `DURA/Services/Import/ImportProvider.swift` — `ImportProvider` protocol, `ImportResult`, `ImportError`
6. `DURA/Views/ContentView.swift` — app structure, navigation, sidebar items, settings tabs
7. `DURA/Views/Editor/NoteDetailView.swift` — main editor with export/publish
8. `DURA/Views/Editor/BlockViews.swift` — all block renderers including `AudioBlockView`
9. `DURA/Services/Podcast/PodcastClipProcessor.swift` — podcast capture pipeline orchestrator
10. `project.yml` — build configuration (includes bridging header for Obj-C)

### Common Tasks
- **Add a new import format:** Create a provider implementing `ImportProvider`, register in `ImportService.init()`. See existing providers for pattern.
- **Add a new export format:** Create a provider implementing `ExportProvider`, add case to `ExportFormat` enum, register in `ExportService.init()`
- **Add a new block type:** Add case to `BlockType` enum, add parsing in `BlockParser`, add rendering in `HTMLExportProvider.renderBlock()`, add view in `BlockViews.swift`
- **Add a SwiftData model:** Define `@Model` class, add to schema in `DURAApp.swift`, add CRUD methods in `DataService`
- **Modify the Kanban board:** Files in `DURA/Views/Kanban/`. Statuses defined in `KanbanStatus.swift`
- **Modify podcast clip pipeline:** Pipeline steps in `PodcastClipProcessor.swift`. Resolution via `PodcastResolverService`, extraction via `AudioSegmentExporter`, transcription via `SpeechTranscriptionService`. To swap out MediaRemote, only change `NowPlayingService.swift`
- **Wire audio playback:** `AudioBlockView` in `BlockViews.swift`. Audio URL is in `block.content`, filename in `block.metadata["filename"]`

### What's NOT Working / Incomplete
- Reading List has partial UI (model + sidebar) but limited functionality
- Wikilinks have no implementation (field only)
- CloudKit sync is disabled
- WordPress.com not supported (only self-hosted WP with Application Passwords; WordPress.com needs OAuth2)
- Block editor is read-only preview; editing is raw markdown
- Podcast clip MediaRemote bridge uses private API (personal use only — see App Store warning in roadmap)

### Next Up: Phase 4 — Wikilinks & Note Graph
The immediate next work is Phase 4 (see roadmap above). Implementation order:
1. Parse `[[note title]]` syntax in markdown
2. Resolve wikilinks to note IDs bidirectionally
3. Backlinks panel in NoteDetailView
4. Note graph visualization

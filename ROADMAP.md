# DURA — Roadmap & As-Built Documentation

> **Last updated:** 2026-02-21
> **Codebase:** ~8,100 lines of Swift across 59 source files
> **Tests:** 166 tests in 26 suites (all passing)
> **Platforms:** macOS 15.0+, iOS 18.0+
> **Swift:** 6.0 with strict concurrency

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
┌─────────────────────────────────────────────┐
│  Views (SwiftUI)                            │
│  ContentView → SidebarView                  │
│             → NoteListContentView           │
│             → NoteDetailView                │
│             → KanbanBoardView               │
│             → WordPressSettingsView          │
├─────────────────────────────────────────────┤
│  Services                                   │
│  DataService (SwiftData CRUD)               │
│  BlockParser (Markdown ↔ Blocks)            │
│  ImportService + 6 ImportProviders          │
│  ExportService + 3 ExportProviders          │
│  WordPressService (REST API)                │
│  WordPressCredentialStore (Keychain)         │
├─────────────────────────────────────────────┤
│  Models (SwiftData @Model + value types)    │
│  Note, Notebook, Tag, Attachment, Bookmark  │
│  Block, DraftMetadata, KanbanStatus, etc.   │
├─────────────────────────────────────────────┤
│  Persistence: SwiftData (local, no CloudKit)│
└─────────────────────────────────────────────┘
```

### Key Patterns

- **Markdown as source of truth** — `Note.body` is always markdown. `Block` arrays are derived via `BlockParser.parse()` and never persisted.
- **Provider pattern** — Import and export use protocol-based providers (`ImportProvider`, `ExportProvider`) registered in service lookup tables. Add a new format by implementing the protocol and registering.
- **JSON-in-SwiftData** — `DraftMetadata` is a `Codable` struct stored as `Data` in `Note.draftMetadataData`, decoded on demand via computed property. Same pattern for `kanbanStatusRaw`/`sourceRaw` using raw string encoding.
- **Strict concurrency** — Swift 6.0 with `Sendable`, `@MainActor`, `actor` (WordPressService). Progress callbacks are `@Sendable`.
- **Cross-platform** — `#if canImport(AppKit)` / `#if canImport(UIKit)` for platform-specific code (text views, PDF generation). Shared everything else.

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
| `ImportSource.swift` | `ImportSource` (enum) | 13 source types (manual, markdown, pdf, docx, image, web, etc.) |
| `KanbanStatus.swift` | `KanbanStatus` (enum) | 7 statuses: none, note, idea, researching, drafting, review, published. `boardStatuses` excludes `.none` |
| `NoteTransferID.swift` | `NoteTransferID` | Lightweight Transferable for Kanban drag-and-drop |

### Services (`DURA/Services/`)

| File | Types | Purpose |
|------|-------|---------|
| `DataService.swift` | `DataService` (@Observable) | Central CRUD for all SwiftData models. ~30 methods. Sorting, filtering, search |
| `BlockParser.swift` | `BlockParser` (struct) | Static `parse(_:)` and `render(_:)`. Line-by-line markdown parsing, handles all 12 block types |

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
| `ContentView.swift` | `ContentView`, `SidebarItem`, `SettingsView`, `GeneralSettingsView` | Root 3-column NavigationSplitView. macOS Settings with General + WordPress tabs |
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
| **Settings/** | | |
| `WordPressSettingsView.swift` | `WordPressSettingsView` | Site URL, username, app password. Test/Save/Clear. Keychain backed |

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
                           └─ embedded: DraftMetadata (JSON)
                              embedded: KanbanStatus (raw string)
                              embedded: ImportSource (raw string)
                              derived:  [Block] (via BlockParser)
```

### SwiftData Schema

Models registered in `DURAApp.swift`:
```swift
Schema([Note.self, Notebook.self, Tag.self, Attachment.self, Bookmark.self])
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
| Import (6 formats) | Done | MD, TXT, RTF, PDF, DOCX, Images with OCR |
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

### Partially Implemented

| Feature | Status | What's Missing |
|---------|--------|----------------|
| Reading List UI | Model only | No dedicated view. Sidebar item exists but not wired |
| Wikilinks | Model only | `linkedNoteIDs` field exists. No parsing, no UI, no bidirectional resolution |
| Block-level editing | Preview only | Blocks render read-only. Editing is raw markdown only |
| WP categories/tags picker | Metadata only | DraftMetadata has fields. No selection UI in editor |
| WP scheduled publishing | Metadata only | `scheduledDate` field exists. No date picker UI |
| WP featured image | Metadata only | `featuredImageId` field exists. No picker or upload |
| Audio blocks | Stub only | `BlockType.audio` enum, `AudioBlockView` display shell (no playback), markdown/HTML serialization. No `AVPlayer`, no import provider, no recording |
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

11. **WordPress.com not supported** — Current implementation uses self-hosted WP REST API with Basic Auth (Application Passwords). WordPress.com sites require OAuth2 via `public-api.wordpress.com`. See Phase 4 roadmap.

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

### Phase 3: Audio Input & Import Enhancements ← NEXT
> **Status:** Planned. Implementation order below.

#### 3a. Audio File Import + Playback
- [ ] Create `AudioImportProvider` — support MP3, M4A, WAV, AIFF, AAC via UTTypes
- [ ] Wire `AVPlayer` playback into existing `AudioBlockView` stub (play/pause/seek)
- [ ] Store audio files as `Attachment` with `.externalStorage`
- [ ] Add `ImportSource.audio` case to `ImportSource` enum
- [ ] Register audio UTTypes in `ImportService` provider lookup
- [ ] Enable drag-and-drop of audio files onto note list

#### 3b. Voice Note Recording
- [ ] Add microphone permission (`NSMicrophoneUsageDescription` in Info.plist)
- [ ] Create `VoiceRecorderView` — record button, waveform visualization, stop/save
- [ ] Use `AVAudioRecorder` to capture M4A audio
- [ ] On save: create new note with audio block + attachment
- [ ] Add recording entry point in toolbar or note list

#### 3c. On-Device Speech-to-Text Transcription
- [ ] Integrate `SFSpeechRecognizer` for on-device transcription (macOS 15+ / iOS 18+)
- [ ] Add `Speech` framework and `NSSpeechRecognitionUsageDescription` permission
- [ ] Post-recording transcription: audio → text inserted as note body below audio block
- [ ] Progress indicator during transcription
- [ ] Fallback handling when on-device recognition unavailable

#### 3d. Expand ClipFolderWatcher
- [ ] Watch all supported import types (PDF, DOCX, RTF, TXT, images, audio) not just `.md`
- [ ] Configure watched extensions in settings
- [ ] Show watcher status and recent imports in UI

#### 3e. HTML Import
- [ ] Create `HTMLImportProvider` — support `.html` and `.htm` files
- [ ] Extract main content (strip nav, footer, scripts) or use full body
- [ ] Convert HTML → Markdown (similar to dura-clipper's Turndown approach, server-side)
- [ ] Register `.html` UTType in `ImportService`

#### 3f. EPUB Import
- [ ] Create `EPUBImportProvider` — parse EPUB (zipped XHTML)
- [ ] Extract text content and inline images from EPUB chapters
- [ ] Convert XHTML → Markdown, concatenate chapters with `## Chapter` headings
- [ ] Register `UTType(filenameExtension: "epub")` in `ImportService`

#### Audio Infrastructure Notes
- `BlockType.audio` already exists with `displayName: "Audio"`, `iconName: "waveform"`
- `AudioBlockView` has UI shell (filename + play icon) but **no AVPlayer** — needs wiring
- `BlockParser` serializes audio as `🔊 [filename](url)` — no reverse parsing yet
- `HTMLExportProvider` renders `<audio controls><source src="..."></audio>`
- `Block.metadata` stores `"filename"` and content stores the URL/path
- No `AVFoundation` import exists anywhere in the codebase currently

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
5. **DataService** is the single CRUD gateway for all SwiftData operations
6. **Tests use Swift Testing** — `@Test`, `#expect`, `@Suite`, `Issue.record()`
7. **ClipFolderWatcher** auto-imports `.md` files from `~/Downloads/DURA-Clips/` via FSEvents
8. **dura-clipper/** is a Chrome extension that clips web pages to markdown with YAML front matter
9. **MarkdownImportProvider** parses YAML front matter for metadata (title, url, tags, notebook, source)
10. **Rich text preview** uses `MarkdownText` view + `isBlockPreview` environment key

### Key Files to Read First
1. `DURA/Models/Note.swift` — central entity, all relationships
2. `DURA/Services/DataService.swift` — all CRUD methods
3. `DURA/Services/BlockParser.swift` — markdown ↔ blocks
4. `DURA/Services/Import/ImportService.swift` — import orchestrator with provider registry
5. `DURA/Services/Import/ImportProvider.swift` — `ImportProvider` protocol, `ImportResult`, `ImportError`
6. `DURA/Views/ContentView.swift` — app structure and navigation
7. `DURA/Views/Editor/NoteDetailView.swift` — main editor with export/publish
8. `DURA/Views/Editor/BlockViews.swift` — all block renderers including `AudioBlockView` stub
9. `project.yml` — build configuration

### Common Tasks
- **Add a new import format:** Create a provider implementing `ImportProvider`, register in `ImportService.init()`. See existing providers for pattern.
- **Add a new export format:** Create a provider implementing `ExportProvider`, add case to `ExportFormat` enum, register in `ExportService.init()`
- **Add a new block type:** Add case to `BlockType` enum, add parsing in `BlockParser`, add rendering in `HTMLExportProvider.renderBlock()`, add view in `BlockViews.swift`
- **Add a SwiftData model:** Define `@Model` class, add to schema in `DURAApp.swift`, add CRUD methods in `DataService`
- **Modify the Kanban board:** Files in `DURA/Views/Kanban/`. Statuses defined in `KanbanStatus.swift`
- **Wire audio playback:** `AudioBlockView` in `BlockViews.swift` has the UI shell. Needs `AVPlayer` wired to the play button. Audio URL is in `block.content`, filename in `block.metadata["filename"]`

### What's NOT Working / Incomplete
- **Audio blocks** — `BlockType.audio` exists, `AudioBlockView` renders a static UI, but no playback (`AVPlayer`), no audio import provider, no recording, no transcription. This is the **next implementation target** (Phase 3).
- Reading List has partial UI (model + sidebar) but limited functionality
- Wikilinks have no implementation (field only)
- CloudKit sync is disabled
- WordPress.com not supported (only self-hosted WP with Application Passwords; WordPress.com needs OAuth2)
- Block editor is read-only preview; editing is raw markdown

### Next Up: Phase 3 — Audio Input & Import Enhancements
The immediate next work is Phase 3 (see roadmap above). Implementation order:
1. **3a** Audio file import provider + wire AVPlayer playback into AudioBlockView
2. **3b** Voice note recording (AVAudioRecorder + mic permission)
3. **3c** On-device speech-to-text (SFSpeechRecognizer)
4. **3d** Expand ClipFolderWatcher to all file types
5. **3e** HTML import provider
6. **3f** EPUB import provider

# DURA — Claude Code Project Guide

Native SwiftUI + SwiftData research note-taking and blog drafting app.

## Build

```bash
xcodegen generate && xcodebuild -scheme DURA_macOS build
xcodebuild -scheme DURA_macOS test   # 166 tests, Swift Testing
```

## Architecture

- **XcodeGen** — `project.yml` is source of truth. Run `xcodegen generate` after adding/removing files.
- **Markdown as source of truth** — `Note.body` is raw markdown. `Block` arrays derived via `BlockParser.parse()`, never persisted.
- **Provider pattern** — Import (9 providers) and Export (3 providers) use `ImportProvider`/`ExportProvider` protocols.
- **JSON-in-SwiftData** — `DraftMetadata` stored as `Data` in `Note.draftMetadataData`. Same for `kanbanStatusRaw`, `sourceRaw`.
- **DataService** — Single CRUD gateway for all models. `@Observable`, not an actor.
- **Cross-platform** — `#if canImport(AppKit)` / `#if canImport(UIKit)`. macOS-only: ClipFolderWatcher, MediaRemote, PodcastClipProcessor.
- **Swift 6.0** strict concurrency — `Sendable`, `@MainActor`, `actor` (WordPressService).
- **Tests** — Swift Testing framework (`@Test`, `#expect`, `@Suite`).

## Schema

```
Notebook ◄─ 1:N ─► Note ◄─ N:M ─► Tag ◄─ N:M ─► Bookmark
                     │
                     ├─ 1:N ─► Attachment
                     ├─ 0:1 ─► PodcastClip
                     └─ embedded: DraftMetadata, KanbanStatus, ImportSource
```

Models registered in `DURAApp.swift`: Note, Notebook, Tag, Attachment, Bookmark, PodcastClip.
Storage: Local SwiftData (no CloudKit). In-memory for tests.

## Key Files

| Purpose | File |
|---------|------|
| Central model | `DURA/Models/Note.swift` |
| All CRUD | `DURA/Services/DataService.swift` |
| Markdown parser | `DURA/Services/BlockParser.swift` |
| Import orchestrator | `DURA/Services/Import/ImportService.swift` |
| Export orchestrator | `DURA/Services/Export/ExportService.swift` |
| App structure | `DURA/Views/ContentView.swift` |
| Main editor | `DURA/Views/Editor/NoteDetailView.swift` |
| Block renderers | `DURA/Views/Editor/BlockViews.swift` |
| Podcast pipeline | `DURA/Services/Podcast/PodcastClipProcessor.swift` |
| Project config | `project.yml` |

## Common Tasks

- **Add import format:** Implement `ImportProvider`, register in `ImportService.init()`
- **Add export format:** Implement `ExportProvider`, add `ExportFormat` case, register in `ExportService.init()`
- **Add block type:** Add `BlockType` case → `BlockParser` → `HTMLExportProvider.renderBlock()` → `BlockViews.swift`
- **Add SwiftData model:** `@Model` class → schema in `DURAApp.swift` → CRUD in `DataService`
- **Swap MediaRemote for App Store:** Replace `NowPlayingService.getCurrentlyPlaying()` — everything downstream unchanged

## Platform Guards

macOS-only features wrapped in `#if os(macOS)`:
- `ClipFolderWatcher` (FSEvents)
- `NowPlayingService` + `PodcastClipProcessor` (private MediaRemote API)
- `MediaRemoteBridge.h/.m` excluded from iOS target in `project.yml`
- iOS uses separate `DURA-iOS.entitlements` (sandbox ON)

## Status

See `ROADMAP.md` for current state and next phases. See `HISTORY.md` for completed phase details.

# DURA Clipper

Chrome extension that clips any webpage as clean Markdown with YAML front matter, ready for import into DURA.

## Installation

1. Open `chrome://extensions/`
2. Enable "Developer mode" (top right)
3. Click "Load unpacked"
4. Select the `dura-clipper/` directory

## Usage

**Popup**: Click the extension icon on any page to open the clip popup. Choose a clip mode, set notebook and tags, then click "Save Clip".

**Context Menu**: Right-click on any page for quick clip options:
- Clip page to DURA (Full Article)
- Clip selection to DURA (Selection Only)
- Save link to DURA (Bookmark)
- Save image to DURA (Image note)

## Clip Modes

- **Full Article**: Extracts main content via Readability.js, converts to Markdown
- **Selection Only**: Clips only the selected text with page metadata
- **Bookmark Only**: Saves title, URL, and description (no body content)

## Output Format

Files are saved as `YYYY-MM-DD-slugified-title.md` in `~/Downloads/DURA-Clips/` (configurable) with YAML front matter containing title, URL, author, tags, notebook, and more.

## Settings

Open the extension's options page to configure:
- Download subfolder
- Default notebook and clip mode
- Notebook list
- Auto-close behavior
- Featured image inclusion

## Importing into DURA

Import the clipped `.md` files using DURA's file import. The YAML front matter is automatically parsed to set metadata including source URL, tags, notebook assignment, and excerpt.

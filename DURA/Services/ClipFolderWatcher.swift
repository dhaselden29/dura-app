import Foundation
import CoreServices
import SwiftUI

/// Monitors a folder for new `.md` files from DURA Clipper and auto-imports them.
///
/// Uses the macOS FSEvents API (`FSEventStream`) to react to file system changes
/// near-instantly without polling. When a new markdown file appears in the watched
/// folder, it is imported via `ImportService`, then moved to a `.imported/` subfolder
/// to prevent re-processing.
@MainActor
@Observable
final class ClipFolderWatcher {
    private let dataService: DataService

    /// Whether the watcher is actively monitoring.
    private(set) var isWatching = false

    /// Most recent auto-import activity for UI feedback.
    private(set) var lastImportedTitle: String?
    private(set) var lastImportedAt: Date?
    private(set) var importedCount: Int = 0

    @ObservationIgnored private var eventStream: FSEventStreamRef?

    /// Files currently being processed (to avoid double-import).
    @ObservationIgnored private var inflight: Set<String> = []

    static let watchedExtensions: Set<String> = [
        "md", "txt", "rtf",
        "pdf", "docx",
        "png", "jpg", "jpeg", "heic", "tiff", "gif", "bmp",
        "mp3", "m4a", "wav", "aiff", "aac",
        "html", "htm",
        "epub",
    ]

    init(dataService: DataService) {
        self.dataService = dataService
    }

    // MARK: - Public API

    /// The folder to watch. Stored in UserDefaults, defaults to `~/Downloads/DURA-Clips`.
    static var watchFolderURL: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: "clipWatchFolder"), !path.isEmpty {
                return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            }
            return defaultWatchFolderURL
        }
        set {
            UserDefaults.standard.set(newValue.path, forKey: "clipWatchFolder")
        }
    }

    static var defaultWatchFolderURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
            .appendingPathComponent("DURA-Clips")
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "clipWatchEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "clipWatchEnabled") }
    }

    func startWatching() {
        guard !isWatching else { return }
        guard ClipFolderWatcher.isEnabled else { return }

        let folderURL = ClipFolderWatcher.watchFolderURL

        // Ensure folder and .imported subfolder exist
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let importedDir = folderURL.appendingPathComponent(".imported")
        try? FileManager.default.createDirectory(at: importedDir, withIntermediateDirectories: true)

        // Process any files already sitting in the folder
        scanAndImport()

        // Start FSEventStream
        startFSEventStream(for: folderURL)
    }

    func stopWatching() {
        stopFSEventStream()
        isWatching = false
    }

    /// Restart watching (e.g. after folder path change).
    func restart() {
        stopWatching()
        inflight.removeAll()
        startWatching()
    }

    // MARK: - FSEvents

    private func startFSEventStream(for folderURL: URL) {
        let pathToWatch = folderURL.path as CFString
        let pathsToWatch = [pathToWatch] as CFArray

        // Store a raw pointer to self for the C callback.
        // Safe because we invalidate the stream in stopWatching() before self goes away.
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, clientInfo, _, _, _, _ in
            guard let clientInfo else { return }
            let watcher = Unmanaged<ClipFolderWatcher>.fromOpaque(clientInfo).takeUnretainedValue()
            Task { @MainActor in
                watcher.scanAndImport()
            }
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,  // latency in seconds — coalesce events within 500ms
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        eventStream = stream
        isWatching = true
    }

    private func stopFSEventStream() {
        guard let stream = eventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
    }

    // MARK: - Scan & Import

    private func scanAndImport() {
        let folderURL = ClipFolderWatcher.watchFolderURL

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        let matchingFiles = contents.filter { url in
            Self.watchedExtensions.contains(url.pathExtension.lowercased()) && !inflight.contains(url.lastPathComponent)
        }

        for fileURL in matchingFiles {
            let filename = fileURL.lastPathComponent
            inflight.insert(filename)

            Task {
                await importAndMove(fileURL: fileURL)
            }
        }
    }

    private func importAndMove(fileURL: URL) async {
        let filename = fileURL.lastPathComponent

        // Brief delay to ensure the file is fully written (Chrome writes in chunks)
        try? await Task.sleep(for: .milliseconds(500))

        // Verify file still exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            inflight.remove(filename)
            return
        }

        let folderURL = ClipFolderWatcher.watchFolderURL
        let importedDir = folderURL.appendingPathComponent(".imported")

        do {
            let service = ImportService(dataService: dataService)
            let note = try await service.importFile(at: fileURL)
            lastImportedTitle = note.title
            lastImportedAt = Date()
            importedCount += 1

            // Move to .imported/ subfolder
            var destination = importedDir.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: destination.path) {
                let stem = filenameStem(filename)
                let ext = (filename as NSString).pathExtension
                let timestamp = Int(Date().timeIntervalSince1970)
                let suffix = ext.isEmpty ? "" : ".\(ext)"
                destination = importedDir.appendingPathComponent("\(stem)-\(timestamp)\(suffix)")
            }
            try FileManager.default.moveItem(at: fileURL, to: destination)
        } catch {
            // Leave file in place so user can retry; allow re-scan next cycle
            inflight.remove(filename)
        }
    }
}

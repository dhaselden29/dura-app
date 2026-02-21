import SwiftUI
import SwiftData

struct PodcastClipsListView: View {
    let dataService: DataService
    @Binding var selectedNote: Note?

    @Query(sort: \PodcastClip.capturedAt, order: .reverse)
    private var clips: [PodcastClip]

    @State private var filterMode: FilterMode = .all
    @State private var searchText = ""

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case resolved = "Resolved"
        case failed = "Failed"

        var status: ClipProcessingStatus? {
            switch self {
            case .all: nil
            case .pending: .pending
            case .resolved: .resolved
            case .failed: .failed
            }
        }
    }

    private var filteredClips: [PodcastClip] {
        var result = clips

        if let status = filterMode.status {
            let raw = status.rawValue
            result = result.filter { $0.processingStatusRaw == raw }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.episodeTitle.lowercased().contains(query) ||
                $0.podcastName.lowercased().contains(query)
            }
        }

        return result
    }

    var body: some View {
        Group {
            if clips.isEmpty {
                ContentUnavailableView(
                    "No Podcast Clips",
                    systemImage: "headphones",
                    description: Text("Play a podcast and press \u{2318}\u{21E7}P to capture a clip.")
                )
            } else if filteredClips.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if filteredClips.isEmpty {
                ContentUnavailableView(
                    "No \(filterMode.rawValue) Clips",
                    systemImage: "headphones",
                    description: Text("No clips match the current filter.")
                )
            } else {
                List {
                    ForEach(filteredClips) { clip in
                        Button {
                            if clip.processingStatus == .resolved, let note = clip.note {
                                selectedNote = note
                            }
                        } label: {
                            PodcastClipRowView(clip: clip)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                dataService.deletePodcastClip(clip)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search clips...")
        .navigationTitle("Podcast Clips")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Filter", selection: $filterMode) {
                    ForEach(FilterMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

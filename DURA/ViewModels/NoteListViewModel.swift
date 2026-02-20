import Foundation
import SwiftData
import SwiftUI

/// Drives the note list view with filtering, sorting, and search capabilities.
@Observable
@MainActor
final class NoteListViewModel {
    private let dataService: DataService

    var searchText: String = ""
    var sortOrder: NoteSortOrder = .modifiedDescending
    var filterNotebook: Notebook?
    var filterTag: Tag?
    var filterKanbanStatus: KanbanStatus?
    var showOnlyDrafts: Bool = false
    var showOnlyFavorites: Bool = false

    var notes: [Note] = []
    var errorMessage: String?

    init(dataService: DataService) {
        self.dataService = dataService
    }

    // MARK: - Fetch

    func refresh() {
        do {
            notes = try dataService.fetchNotes(
                sortBy: sortOrder,
                notebook: filterNotebook,
                tag: filterTag,
                kanbanStatus: filterKanbanStatus,
                onlyDrafts: showOnlyDrafts,
                onlyFavorites: showOnlyFavorites,
                searchText: searchText
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Actions

    func createNote(title: String = "", in notebook: Notebook? = nil) -> Note {
        let target = notebook ?? filterNotebook
        let note = dataService.createNote(title: title, notebook: target)
        refresh()
        return note
    }

    func deleteNote(_ note: Note) {
        dataService.deleteNote(note)
        refresh()
    }

    func deleteNotes(at offsets: IndexSet) {
        let toDelete = offsets.map { notes[$0] }
        dataService.deleteNotes(toDelete)
        refresh()
    }

    func togglePin(_ note: Note) {
        dataService.togglePin(note)
        refresh()
    }

    func toggleFavorite(_ note: Note) {
        dataService.toggleFavorite(note)
        refresh()
    }

    func moveNote(_ note: Note, to notebook: Notebook?) {
        dataService.moveNote(note, to: notebook)
        refresh()
    }

    // MARK: - Filter Helpers

    func clearFilters() {
        filterNotebook = nil
        filterTag = nil
        filterKanbanStatus = nil
        showOnlyDrafts = false
        showOnlyFavorites = false
        searchText = ""
        refresh()
    }

    var hasActiveFilters: Bool {
        filterNotebook != nil ||
        filterTag != nil ||
        filterKanbanStatus != nil ||
        showOnlyDrafts ||
        showOnlyFavorites ||
        !searchText.isEmpty
    }

    var filterDescription: String {
        var parts: [String] = []
        if let nb = filterNotebook { parts.append(nb.name) }
        if let tag = filterTag { parts.append("#\(tag.name)") }
        if let status = filterKanbanStatus { parts.append(status.displayName) }
        if showOnlyDrafts { parts.append("Drafts") }
        if showOnlyFavorites { parts.append("Favorites") }
        return parts.isEmpty ? "All Notes" : parts.joined(separator: " / ")
    }
}

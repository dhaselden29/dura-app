import SwiftUI

struct KanbanColumnView: View {
    let status: KanbanStatus
    let notes: [Note]
    let allNotes: [Note]
    let connectedNoteIDs: Set<UUID>
    @Binding var selectedNote: Note?
    let dataService: DataService
    var startCollapsed: Bool = false

    @State private var isCollapsed: Bool = false
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header with collapse toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                    Image(systemName: status.iconName)
                        .foregroundStyle(.secondary)
                    Text(status.displayName)
                        .font(.headline)
                    Text("\(notes.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.2))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                Divider()

                // Scrollable card list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(notes) { note in
                            KanbanCardView(
                                note: note,
                                isSelected: selectedNote?.id == note.id,
                                isConnected: connectedNoteIDs.contains(note.id),
                                dataService: dataService
                            )
                            .draggable(NoteTransferID(id: note.id))
                            .onTapGesture {
                                selectedNote = note
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
        )
        .dropDestination(for: NoteTransferID.self) { items, _ in
            guard let transferID = items.first else { return false }
            guard let note = allNotes.first(where: { $0.id == transferID.id }) else { return false }
            guard note.kanbanStatus != status else { return false }
            dataService.setKanbanStatus(status, for: note)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .onAppear {
            isCollapsed = startCollapsed
        }
    }
}

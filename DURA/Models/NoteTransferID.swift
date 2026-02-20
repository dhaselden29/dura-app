import Foundation
import UniformTypeIdentifiers
import CoreTransferable

/// Lightweight identifier used for drag-and-drop on the Kanban board.
/// Avoids serializing the full SwiftData model graph.
struct NoteTransferID: Codable, Hashable, Sendable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .noteTransferID)
    }
}

extension UTType {
    static let noteTransferID = UTType(exportedAs: "com.dura.note-transfer-id")
}

import Foundation
import SwiftData

@Model
final class Notebook {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String?
    var color: String?
    var sortOrder: Int = 0

    @Relationship
    var parentNotebook: Notebook?

    @Relationship(deleteRule: .cascade, inverse: \Notebook.parentNotebook)
    var children: [Notebook]? = []

    @Relationship(deleteRule: .nullify)
    var notes: [Note]? = []

    init(
        name: String = "",
        icon: String? = nil,
        color: String? = nil,
        parentNotebook: Notebook? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.parentNotebook = parentNotebook
    }
}

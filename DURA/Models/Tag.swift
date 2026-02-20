import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var color: String?

    @Relationship
    var notes: [Note]? = []

    @Relationship
    var bookmarks: [Bookmark]? = []

    init(name: String = "", color: String? = nil) {
        self.id = UUID()
        self.name = name
        self.color = color
    }
}

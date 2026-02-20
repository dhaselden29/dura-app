import Foundation
import SwiftData

@Model
final class Bookmark {
    var id: UUID = UUID()
    var url: String = ""
    var title: String = ""
    var excerpt: String?
    @Attribute(.externalStorage)
    var thumbnailData: Data?
    var isRead: Bool = false
    var addedAt: Date = Date()

    @Relationship(inverse: \Tag.bookmarks)
    var tags: [Tag]? = []

    init(
        url: String = "",
        title: String = "",
        excerpt: String? = nil
    ) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.excerpt = excerpt
        self.addedAt = Date()
    }
}

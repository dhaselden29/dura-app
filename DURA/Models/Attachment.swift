import Foundation
import SwiftData

@Model
final class Attachment {
    var id: UUID = UUID()
    var filename: String = ""
    @Attribute(.externalStorage)
    var data: Data?
    var mimeType: String = ""
    var ocrText: String?

    @Relationship
    var note: Note?

    init(
        filename: String = "",
        data: Data? = nil,
        mimeType: String = "",
        note: Note? = nil
    ) {
        self.id = UUID()
        self.filename = filename
        self.data = data
        self.mimeType = mimeType
        self.note = note
    }
}

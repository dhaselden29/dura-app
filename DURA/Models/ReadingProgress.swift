import Foundation

struct ReadingProgress: Codable, Hashable, Sendable {
    var percentRead: Double = 0.0
    var readAt: Date?
    var lastReadDate: Date?
}

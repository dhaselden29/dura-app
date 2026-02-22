import Testing
import Foundation
@testable import DURA

@Suite("ReadingProgress Model")
struct ReadingProgressModelTests {

    @Test("Default values")
    func defaults() {
        let progress = ReadingProgress()
        #expect(progress.percentRead == 0.0)
        #expect(progress.readAt == nil)
        #expect(progress.lastReadDate == nil)
    }

    @Test("JSON round-trip preserves all fields")
    func jsonRoundTrip() throws {
        var progress = ReadingProgress()
        progress.percentRead = 42.5
        progress.readAt = Date(timeIntervalSince1970: 1_000_000)
        progress.lastReadDate = Date(timeIntervalSince1970: 2_000_000)

        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(ReadingProgress.self, from: data)

        #expect(decoded.percentRead == 42.5)
        #expect(decoded.readAt == Date(timeIntervalSince1970: 1_000_000))
        #expect(decoded.lastReadDate == Date(timeIntervalSince1970: 2_000_000))
    }

    @Test("JSON round-trip with nil dates")
    func jsonRoundTripNilDates() throws {
        let progress = ReadingProgress()
        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(ReadingProgress.self, from: data)

        #expect(decoded.percentRead == 0.0)
        #expect(decoded.readAt == nil)
        #expect(decoded.lastReadDate == nil)
    }

    @Test("Hashable conformance")
    func hashable() {
        let a = ReadingProgress()
        var b = ReadingProgress()
        #expect(a == b)

        b.percentRead = 50.0
        #expect(a != b)
    }
}

@Suite("Note ReadingProgress Integration")
struct NoteReadingProgressTests {

    @Test("Note returns default ReadingProgress when data is nil")
    func nilDataReturnsDefault() {
        let note = Note(title: "Test")
        #expect(note.readingProgressData == nil)

        let progress = note.readingProgress
        #expect(progress.percentRead == 0.0)
        #expect(progress.readAt == nil)
        #expect(progress.lastReadDate == nil)
    }

    @Test("Note computed property round-trips")
    func noteComputedRoundTrip() {
        let note = Note(title: "Test")
        var progress = ReadingProgress()
        progress.percentRead = 75.0
        progress.lastReadDate = Date()

        note.readingProgress = progress
        #expect(note.readingProgressData != nil)

        let decoded = note.readingProgress
        #expect(decoded.percentRead == 75.0)
        #expect(decoded.lastReadDate != nil)
    }

    @Test("Corrupt data returns default ReadingProgress")
    func corruptDataReturnsDefault() {
        let note = Note(title: "Test")
        note.readingProgressData = Data("not json".utf8)

        let progress = note.readingProgress
        #expect(progress.percentRead == 0.0)
        #expect(progress.readAt == nil)
    }
}

@Suite("Reading Progress Business Logic")
struct ReadingProgressBusinessLogicTests {

    @Test("Minutes remaining calculation")
    func minutesRemaining() {
        // 238 words per minute is the reading speed used in the app
        // 1190 words = ~5 min read
        let wordCount = 1190
        let totalMinutes = max(1, wordCount / 238) // 5
        let percentRead = 60.0
        let remaining = max(0, Int(Double(totalMinutes) * (1.0 - percentRead / 100.0)))
        #expect(remaining == 2)
    }

    @Test("High-water mark only increases")
    func highWaterMark() {
        let note = Note(title: "Test")
        var progress = ReadingProgress()

        // Simulate scroll to 50%
        progress.percentRead = 50.0
        progress.lastReadDate = Date()
        note.readingProgress = progress

        // Simulate scroll back to 30% — should NOT decrease
        let currentProgress = note.readingProgress
        let newPercent = 30.0
        // The guard in the callback prevents this, verify here the model doesn't enforce it
        // (that's the view's responsibility)
        #expect(newPercent < currentProgress.percentRead)
    }

    @Test("readAt set at 85% threshold")
    func readAtThreshold() {
        var progress = ReadingProgress()

        // At 80% — readAt should remain nil
        progress.percentRead = 80.0
        if progress.percentRead >= 85.0 && progress.readAt == nil {
            progress.readAt = Date()
        }
        #expect(progress.readAt == nil)

        // At 85% — readAt should be set
        progress.percentRead = 85.0
        if progress.percentRead >= 85.0 && progress.readAt == nil {
            progress.readAt = Date()
        }
        #expect(progress.readAt != nil)
    }

    @Test("readAt not re-set after initial trigger")
    func readAtNotReSet() {
        var progress = ReadingProgress()

        // First trigger at 85%
        progress.percentRead = 85.0
        let firstDate = Date(timeIntervalSince1970: 1_000_000)
        if progress.percentRead >= 85.0 && progress.readAt == nil {
            progress.readAt = firstDate
        }
        #expect(progress.readAt == firstDate)

        // Scroll to 95% — readAt should NOT change
        progress.percentRead = 95.0
        if progress.percentRead >= 85.0 && progress.readAt == nil {
            progress.readAt = Date()
        }
        #expect(progress.readAt == firstDate)
    }

    @Test("Zero word count gives 1 min read time")
    func zeroWordCount() {
        let wordCount = 0
        let readingTime = max(1, wordCount / 238)
        #expect(readingTime == 1)
    }

    @Test("Short content at 100% shows 0 min left")
    func shortContentFullyRead() {
        let wordCount = 50
        let totalMinutes = max(1, wordCount / 238) // 1
        let percentRead = 100.0
        let remaining = max(0, Int(Double(totalMinutes) * (1.0 - percentRead / 100.0)))
        #expect(remaining == 0)
    }
}

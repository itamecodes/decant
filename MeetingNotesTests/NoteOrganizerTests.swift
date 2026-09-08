import XCTest
@testable import MeetingNotes

final class NoteOrganizerTests: XCTestCase {

    private var calendar: Calendar { Calendar(identifier: .gregorian) }
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func note(_ title: String, daysAgo: Int, pinned: Bool = false, starred: Bool = false) -> Note {
        let created = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        let n = Note(createdAt: created, title: title, transcript: "t", summary: "s")
        n.isPinned = pinned
        n.isStarred = starred
        return n
    }

    func testPinnedSectionComesFirst() {
        let notes = [
            note("Today A", daysAgo: 0),
            note("Pinned old", daysAgo: 5, pinned: true),
            note("Yesterday B", daysAgo: 1),
        ]
        let sections = NoteOrganizer.sections(notes, now: now, calendar: calendar)

        XCTAssertEqual(sections.first?.title, "Pinned")
        XCTAssertTrue(sections.first?.isPinned == true)
        XCTAssertEqual(sections.first?.entries.map { $0.note.title }, ["Pinned old"])
        // Pinned note must not also appear in a day group.
        let dayTitles = sections.dropFirst().flatMap { $0.entries.map { $0.note.title } }
        XCTAssertFalse(dayTitles.contains("Pinned old"))
        XCTAssertEqual(Set(dayTitles), ["Today A", "Yesterday B"])
    }

    func testCaptureNumberIsStableRegardlessOfPinning() {
        // Newest note gets the highest number, even if an older note is pinned.
        let notes = [
            note("newest", daysAgo: 0),
            note("middle", daysAgo: 1, pinned: true),
            note("oldest", daysAgo: 2),
        ]
        let sections = NoteOrganizer.sections(notes, now: now, calendar: calendar)
        var number = [String: Int]()
        for s in sections { for e in s.entries { number[e.note.title] = e.number } }
        XCTAssertEqual(number["newest"], 3)
        XCTAssertEqual(number["middle"], 2)
        XCTAssertEqual(number["oldest"], 1)
    }

    func testStarredOnlyFilter() {
        let notes = [
            note("keep", daysAgo: 0, starred: true),
            note("drop", daysAgo: 0, starred: false),
            note("keep pinned", daysAgo: 3, pinned: true, starred: true),
            note("drop pinned", daysAgo: 3, pinned: true, starred: false),
        ]
        let sections = NoteOrganizer.sections(notes, starredOnly: true, now: now, calendar: calendar)
        let titles = sections.flatMap { $0.entries.map { $0.note.title } }
        XCTAssertEqual(Set(titles), ["keep", "keep pinned"])
        XCTAssertEqual(sections.first?.title, "Pinned")   // starred pinned still leads
    }

    func testNoPinnedSectionWhenNonePinned() {
        let sections = NoteOrganizer.sections([note("a", daysAgo: 0)], now: now, calendar: calendar)
        XCTAssertEqual(sections.first?.title, "Today")
        XCTAssertFalse(sections.contains { $0.isPinned })
    }
}

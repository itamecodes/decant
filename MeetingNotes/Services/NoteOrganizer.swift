import Foundation

/// A note plus its stable "capture number" (chronological rank across all notes,
/// independent of pinning or filtering).
struct NoteEntry: Identifiable {
    let note: Note
    let number: Int
    var id: UUID { note.id }
}

/// A titled section of the list: the pinned group, or a day group.
struct NoteSection: Identifiable {
    let id: String
    let title: String
    let isPinned: Bool
    let entries: [NoteEntry]
}

/// Pure transform from stored notes into the list's sections: pinned notes first,
/// then the rest grouped by day, with an optional "starred only" filter. Kept free
/// of SwiftUI/SwiftData so it can be unit-tested with plain `Note` values.
enum NoteOrganizer {
    static func sections(
        _ notes: [Note],
        starredOnly: Bool = false,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [NoteSection] {
        // Capture numbers are assigned over ALL notes, newest = highest, so a
        // note keeps the same number whether or not it's pinned or filtered.
        let ranked = notes.sorted { $0.createdAt > $1.createdAt }
        var number = [UUID: Int]()
        for (offset, note) in ranked.enumerated() {
            number[note.id] = ranked.count - offset
        }
        func entry(_ note: Note) -> NoteEntry { NoteEntry(note: note, number: number[note.id] ?? 0) }

        let visible = starredOnly ? notes.filter(\.isStarred) : notes

        var sections: [NoteSection] = []

        // Pinned section (newest first), above everything.
        let pinned = visible.filter(\.isPinned).sorted { $0.createdAt > $1.createdAt }
        if !pinned.isEmpty {
            sections.append(NoteSection(id: "pinned", title: "Pinned", isPinned: true,
                                        entries: pinned.map(entry)))
        }

        // Remaining notes grouped by calendar day, newest day first.
        let unpinned = visible.filter { !$0.isPinned }
        let byDay = Dictionary(grouping: unpinned) { calendar.startOfDay(for: $0.createdAt) }
        for day in byDay.keys.sorted(by: >) {
            let dayNotes = (byDay[day] ?? []).sorted { $0.createdAt > $1.createdAt }
            sections.append(NoteSection(
                id: ISO8601DateFormatter().string(from: day),
                title: dayTitle(day, now: now, calendar: calendar),
                isPinned: false,
                entries: dayNotes.map(entry)
            ))
        }
        return sections
    }

    static func dayTitle(_ day: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: calendar.startOfDay(for: now)) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)),
           calendar.isDate(day, inSameDayAs: yesterday) { return "Yesterday" }
        if let days = calendar.dateComponents([.day], from: day, to: calendar.startOfDay(for: now)).day,
           days < 7 {
            return day.formatted(.dateTime.weekday(.wide))
        }
        return day.formatted(.dateTime.month().day().year())
    }
}

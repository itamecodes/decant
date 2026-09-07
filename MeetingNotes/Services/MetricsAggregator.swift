import Foundation

/// One day's totals for the daily charts.
struct DailyBucket: Identifiable {
    let date: Date
    let cost: Double
    let count: Int
    var id: Date { date }
}

/// One recording's metrics for the per-recording charts.
struct RecordingPoint: Identifiable {
    let id: UUID
    let index: Int          // 1-based position within the window (oldest → newest)
    let latency: TimeInterval
    let cost: Double
    let minutes: Double     // recording length, encoded as bar color
}

/// Pure transforms from stored notes into chart-ready series. Kept free of
/// SwiftUI and SwiftData so it can be unit-tested with plain `Note` values.
enum MetricsAggregator {

    /// A bucket for each of the last `days` calendar days (oldest first),
    /// including empty days, summing cost and counting notes.
    static func dailyBuckets(
        _ notes: [Note],
        days: Int = 14,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyBucket] {
        let today = calendar.startOfDay(for: now)
        let byDay = Dictionary(grouping: notes) { calendar.startOfDay(for: $0.createdAt) }

        return (0..<max(days, 0)).reversed().compactMap { offset -> DailyBucket? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayNotes = byDay[day] ?? []
            return DailyBucket(
                date: day,
                cost: dayNotes.reduce(0) { $0 + $1.estimatedCost },
                count: dayNotes.count
            )
        }
    }

    /// The most recent `limit` recordings, oldest → newest, indexed 1…n.
    static func recentRecordings(_ notes: [Note], limit: Int = 20) -> [RecordingPoint] {
        let ordered = notes.sorted { $0.createdAt < $1.createdAt }.suffix(limit)
        return ordered.enumerated().map { offset, note in
            RecordingPoint(
                id: note.id,
                index: offset + 1,
                latency: note.transcriptionLatency + note.summaryLatency,
                cost: note.estimatedCost,
                minutes: note.duration / 60
            )
        }
    }
}

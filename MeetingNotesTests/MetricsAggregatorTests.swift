import XCTest
@testable import MeetingNotes

final class MetricsAggregatorTests: XCTestCase {

    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    private func note(daysAgo: Int, cost: Double = 0, latency: TimeInterval = 0,
                      minutes: Double = 0, now: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> Note {
        let created = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        let n = Note(createdAt: created, title: "t", transcript: "t", summary: "s",
                     duration: minutes * 60)
        n.estimatedCost = cost
        n.transcriptionLatency = latency
        return n
    }

    func testDailyBucketsCoverWindowOldestFirstAndSumPerDay() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let notes = [
            note(daysAgo: 0, cost: 0.10, now: now),
            note(daysAgo: 0, cost: 0.05, now: now),   // same day → summed
            note(daysAgo: 2, cost: 0.20, now: now),
            note(daysAgo: 30, cost: 9.99, now: now),  // outside 14-day window
        ]

        let buckets = MetricsAggregator.dailyBuckets(notes, days: 14, now: now, calendar: calendar)

        XCTAssertEqual(buckets.count, 14)
        XCTAssertLessThan(buckets.first!.date, buckets.last!.date)   // oldest first
        XCTAssertEqual(buckets.last!.cost, 0.15, accuracy: 0.0001)   // today = 0.10 + 0.05
        XCTAssertEqual(buckets.last!.count, 2)
        XCTAssertEqual(buckets[11].cost, 0.20, accuracy: 0.0001)     // two days ago
        // The 30-days-ago note is excluded, so the total across the window is 0.35.
        XCTAssertEqual(buckets.reduce(0) { $0 + $1.cost }, 0.35, accuracy: 0.0001)
    }

    func testDailyBucketsEmptyStillFillsWindow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let buckets = MetricsAggregator.dailyBuckets([], days: 7, now: now, calendar: calendar)
        XCTAssertEqual(buckets.count, 7)
        XCTAssertTrue(buckets.allSatisfy { $0.count == 0 && $0.cost == 0 })
    }

    func testRecentRecordingsWindowsAndIndexesOldestFirst() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        // 25 notes, one per day going back; newest is daysAgo 0.
        let notes = (0..<25).map { note(daysAgo: $0, cost: Double($0), latency: Double($0), minutes: Double($0), now: now) }

        let points = MetricsAggregator.recentRecordings(notes, limit: 20)

        XCTAssertEqual(points.count, 20)
        XCTAssertEqual(points.first!.index, 1)
        XCTAssertEqual(points.last!.index, 20)
        // Oldest in the window is daysAgo 19 (cost 19); newest is daysAgo 0 (cost 0).
        XCTAssertEqual(points.first!.cost, 19, accuracy: 0.0001)
        XCTAssertEqual(points.last!.cost, 0, accuracy: 0.0001)
        // minutes derived from duration
        XCTAssertEqual(points.first!.minutes, 19, accuracy: 0.0001)
    }

    func testRecentRecordingsFewerThanLimit() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let points = MetricsAggregator.recentRecordings([note(daysAgo: 1, now: now)], limit: 20)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first!.index, 1)
    }
}

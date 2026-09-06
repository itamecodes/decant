import Foundation
import SwiftData

/// A single saved note: the transcript plus its AI-generated summary and action items.
@Model
final class Note {
    var id: UUID
    var createdAt: Date
    var title: String
    var transcript: String
    var summary: String

    /// Length of the source audio in seconds (0 if unknown).
    var duration: TimeInterval = 0

    /// Ordered action items. Deleting the note deletes its items.
    @Relationship(deleteRule: .cascade)
    var actionItems: [ActionItem]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        title: String,
        transcript: String,
        summary: String,
        duration: TimeInterval = 0,
        actionItems: [ActionItem] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.transcript = transcript
        self.summary = summary
        self.duration = duration
        self.actionItems = actionItems
    }
}

extension Note {
    /// Number of completed action items.
    var completedCount: Int { actionItems.filter(\.done).count }

    /// Number of open (incomplete) action items.
    var openCount: Int { actionItems.filter { !$0.done }.count }

    /// Duration formatted as m:ss or mm:ss.
    var durationText: String {
        let total = Int(duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Approximate word count of the transcript.
    var wordCount: Int {
        transcript.split { $0 == " " || $0 == "\n" || $0 == "\t" }.count
    }

    /// Word count with a thousands separator, e.g. "3,412".
    var wordCountText: String {
        wordCount.formatted(.number.grouping(.automatic))
    }

    /// Action items rendered as a plain-text checklist, for copy/share.
    var actionItemsText: String {
        actionItems
            .map { "\($0.done ? "[x]" : "[ ]") \($0.text)" }
            .joined(separator: "\n")
    }

    /// The whole note formatted as text, for the default share payload.
    var shareText: String {
        var parts = ["# \(title)"]
        if !summary.isEmpty {
            parts.append("## Summary\n\(summary)")
        }
        if !actionItems.isEmpty {
            parts.append("## Action Items\n\(actionItemsText)")
        }
        if !transcript.isEmpty {
            parts.append("## Transcript\n\(transcript)")
        }
        return parts.joined(separator: "\n\n")
    }
}

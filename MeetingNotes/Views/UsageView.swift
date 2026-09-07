import SwiftUI
import SwiftData

/// Aggregate, on-device usage metrics across all notes: estimated spend,
/// latency, tokens, and a per-model breakdown. Nothing here leaves the device.
struct UsageView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var notes: [Note]

    private var totalSpend: Double { notes.reduce(0) { $0 + $1.estimatedCost } }
    private var audioMinutes: Double { notes.reduce(0) { $0 + $1.duration } / 60 }
    private var totalTokens: Int { notes.reduce(0) { $0 + $1.totalTokens } }

    private var avgTranscribe: TimeInterval { average(\.transcriptionLatency) }
    private var avgSummarize: TimeInterval { average(\.summaryLatency) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Usage")
                    .font(Theme.head(28))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button { dismiss() } label: {
                    Text("DONE").font(Theme.head(12)).tracking(1.2).foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.divider).frame(height: 1) }

            if notes.isEmpty {
                Spacer()
                Text("No notes yet")
                    .font(Theme.head(22))
                    .foregroundStyle(Theme.ink(0.5))
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        headline
                        stats
                        modelBreakdown
                        Text("Estimates only, computed on-device from built-in rates. Actual charges come from your provider.")
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.ink(0.5))
                            .lineSpacing(2)
                    }
                    .padding(20)
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .tint(Theme.accent)
    }

    // MARK: - Sections

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: "Estimated spend · all notes", size: 10, em: 0.16, color: Theme.accent700)
            Text(Note.formatCost(totalSpend))
                .font(Theme.head(56))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
        }
    }

    private var stats: some View {
        VStack(spacing: 0) {
            row("Notes", "\(notes.count)")
            divider
            row("Audio processed", String(format: "%.0f min", audioMinutes))
            divider
            row("Avg. transcribe", Note.formatLatency(avgTranscribe))
            divider
            row("Avg. summarize", Note.formatLatency(avgSummarize))
            divider
            row("Total tokens", totalTokens > 0 ? totalTokens.formatted(.number.grouping(.automatic)) : "—")
        }
        .overlay(Rectangle().strokeBorder(Theme.divider, lineWidth: 1))
    }

    @ViewBuilder private var modelBreakdown: some View {
        let groups = modelGroups
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "By summary model", size: 11, em: 0.16, color: Theme.accent700, heading: true)
                ForEach(groups, id: \.model) { group in
                    HStack(alignment: .firstTextBaseline) {
                        Text(group.model)
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.text)
                        Text("· \(group.count)")
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.ink(0.45))
                        Spacer(minLength: 12)
                        Text(Note.formatCost(group.cost))
                            .font(Theme.head(15))
                            .monospacedDigit()
                            .foregroundStyle(Theme.text)
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink(0.08)).frame(height: 1) }
                }
            }
        }
    }

    // MARK: - Building blocks

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.body(13)).foregroundStyle(Theme.ink(0.6))
            Spacer()
            Text(value).font(Theme.head(17)).monospacedDigit().foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var divider: some View { Rectangle().fill(Theme.ink(0.08)).frame(height: 1) }

    private func average(_ keyPath: KeyPath<Note, TimeInterval>) -> TimeInterval {
        let vals = notes.map { $0[keyPath: keyPath] }.filter { $0 > 0 }
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private var modelGroups: [(model: String, count: Int, cost: Double)] {
        let named = notes.filter { !$0.summaryModel.isEmpty }
        let grouped = Dictionary(grouping: named, by: { $0.summaryModel })
        return grouped
            .map { (model: $0.key, count: $0.value.count, cost: $0.value.reduce(0) { $0 + $1.estimatedCost }) }
            .sorted { $0.cost > $1.cost }
    }
}

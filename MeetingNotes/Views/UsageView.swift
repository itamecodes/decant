import SwiftUI
import SwiftData
import Charts

/// Aggregate, on-device usage metrics across all notes: charts of daily spend
/// and volume, per-recording latency and cost, plus totals. Nothing here leaves
/// the device.
struct UsageView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var notes: [Note]

    private var totalSpend: Double { notes.reduce(0) { $0 + $1.estimatedCost } }
    private var audioMinutes: Double { notes.reduce(0) { $0 + $1.duration } / 60 }
    private var totalTokens: Int { notes.reduce(0) { $0 + $1.totalTokens } }

    private var avgTranscribe: TimeInterval { average(\.transcriptionLatency) }
    private var avgSummarize: TimeInterval { average(\.summaryLatency) }

    private var dailyBuckets: [DailyBucket] { MetricsAggregator.dailyBuckets(notes) }
    private var recordings: [RecordingPoint] { MetricsAggregator.recentRecordings(notes) }
    private var maxMinutes: Double { max(recordings.map(\.minutes).max() ?? 0, 0.0001) }

    /// Bar color for a recording, darker/accent for longer clips.
    private func lengthColor(_ minutes: Double) -> Color {
        Theme.accent.opacity(0.35 + 0.65 * min(minutes / maxMinutes, 1))
    }

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
                        dailyCharts
                        recordingCharts
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

    // MARK: - Charts

    private var dailyCharts: some View {
        VStack(alignment: .leading, spacing: 22) {
            chartBlock(title: "Spend / day", caption: "Last 14 days") {
                Chart(dailyBuckets) { bucket in
                    BarMark(
                        x: .value("Day", bucket.date, unit: .day),
                        y: .value("Spend", bucket.cost)
                    )
                    .cornerRadius(0)
                    .foregroundStyle(Theme.accent)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartXAxis { dayAxis }
                .frame(height: 120)
            }
            chartBlock(title: "Notes / day", caption: "Last 14 days") {
                Chart(dailyBuckets) { bucket in
                    BarMark(
                        x: .value("Day", bucket.date, unit: .day),
                        y: .value("Notes", bucket.count)
                    )
                    .cornerRadius(0)
                    .foregroundStyle(Theme.accent)
                }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
                .chartXAxis { dayAxis }
                .frame(height: 120)
            }
        }
    }

    private var recordingCharts: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Eyebrow(text: "By recording", size: 11, em: 0.16, color: Theme.accent700, heading: true)
                Spacer()
                lengthLegend
            }
            chartBlock(title: "Latency", caption: "seconds") {
                recordingChart { $0.latency }
            }
            chartBlock(title: "Cost", caption: "USD") {
                recordingChart { $0.cost }
            }
        }
    }

    private func recordingChart(_ value: @escaping (RecordingPoint) -> Double) -> some View {
        Chart(recordings) { point in
            BarMark(
                x: .value("Recording", point.index),
                y: .value("Value", value(point))
            )
            .cornerRadius(0)
            .foregroundStyle(lengthColor(point.minutes))
        }
        .chartXAxis(.hidden)
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
        .frame(height: 120)
    }

    private var dayAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: 3)) { _ in
            AxisGridLine()
            AxisTick()
            AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
        }
    }

    /// Color key: length is encoded as bar shade.
    private var lengthLegend: some View {
        HStack(spacing: 6) {
            Text("shorter").font(Theme.body(10)).foregroundStyle(Theme.ink(0.5))
            LinearGradient(
                colors: [Theme.accent.opacity(0.35), Theme.accent],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: 46, height: 7)
            Text("longer").font(Theme.body(10)).foregroundStyle(Theme.ink(0.5))
        }
    }

    private func chartBlock<Content: View>(
        title: String, caption: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(Theme.head(17)).foregroundStyle(Theme.text)
                Text(caption).font(Theme.body(11)).foregroundStyle(Theme.ink(0.45))
            }
            content()
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

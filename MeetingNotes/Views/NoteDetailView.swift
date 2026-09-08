import SwiftUI
import SwiftData

/// A note as a technical document (design 1a): a stat header, then a switch
/// between Overview (summary + action items) and the Transcript.
struct NoteDetailView: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0   // 0 = Overview, 1 = Transcript

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: stamp)
                    Text(note.title)
                        .font(Theme.head(33))
                        .tracking(-0.33)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        .padding(.bottom, 14)

                    statRow.padding(.bottom, 20)

                    IndustrySegmented(options: ["Overview", "Transcript"], selection: $tab)
                        .padding(.bottom, 22)

                    if tab == 0 { overview } else { transcript }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 44)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                    Text("NOTES").font(Theme.head(12)).tracking(1.2)
                }
                .foregroundStyle(Theme.accent)
            }
            .buttonStyle(PressableStyle())

            Spacer()

            Button {
                withAnimation { note.isStarred.toggle() }
            } label: {
                Image(systemName: note.isStarred ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(note.isStarred ? Theme.accent : Theme.text)
                    .frame(width: 36, height: 36)
                    .overlay(Rectangle().strokeBorder(note.isStarred ? Theme.accent : Theme.divider, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .padding(.trailing, 8)

            Menu {
                ShareLink(item: note.shareText) { Label("Share note", systemImage: "square.and.arrow.up") }
                Divider()
                Button { UIPasteboard.general.string = note.summary } label: { Label("Copy summary", systemImage: "text.alignleft") }
                Button { UIPasteboard.general.string = note.actionItemsText } label: { Label("Copy action items", systemImage: "checklist") }
                Button { UIPasteboard.general.string = note.transcript } label: { Label("Copy transcript", systemImage: "waveform") }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.text)
                    .frame(width: 36, height: 36)
                    .overlay(Rectangle().strokeBorder(Theme.divider, lineWidth: 1))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Stat row

    private var statRow: some View {
        HStack(spacing: 0) {
            stat("Length", note.duration > 0 ? note.durationText : "—")
            stat("Words", note.wordCountText)
            stat("Actions", "\(note.completedCount)/\(note.actionItems.count)")
        }
        .padding(.vertical, 9)
        .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.divider).frame(height: 1) }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Eyebrow(text: label, size: 9.5, em: 0.14, color: Theme.ink(0.48))
            Text(value)
                .font(Theme.head(17))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Overview

    private var overview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Summary", size: 11, em: 0.16, color: Theme.accent700, heading: true)
                .padding(.bottom, 8)
            Text(note.summary.isEmpty ? "No summary." : note.summary)
                .font(Theme.body(14.5))
                .lineSpacing(4)
                .foregroundStyle(note.summary.isEmpty ? Theme.ink(0.5) : Theme.text)
                .textSelection(.enabled)
                .padding(.bottom, 26)

            HStack(spacing: 10) {
                Eyebrow(text: "Action items", size: 11, em: 0.16, color: Theme.accent700, heading: true)
                Rectangle().fill(Theme.divider).frame(height: 1)
                Text("\(note.completedCount)/\(note.actionItems.count)")
                    .font(Theme.body(11))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink(0.5))
            }
            .padding(.bottom, 6)

            if note.actionItems.isEmpty {
                Text("No action items.")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.ink(0.5))
                    .padding(.vertical, 14)
            } else {
                ForEach(note.actionItems) { item in
                    ActionItemRow(item: item)
                }
            }

            runPanel.padding(.top, 28)
        }
    }

    /// A blueprint "spec" panel of the run metrics for this note.
    private var runPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: "Run", size: 10, em: 0.1, color: Theme.accent)
                Spacer()
                Text("est.").font(Theme.body(10)).foregroundStyle(Theme.ink(0.45))
            }
            runRow("Est. cost", note.estimatedCostText)
            runRow("Transcribe", Note.formatLatency(note.transcriptionLatency))
            runRow("Summarize", Note.formatLatency(note.summaryLatency))
            runRow("Tokens", note.totalTokens > 0 ? "\(note.promptTokens) in · \(note.completionTokens) out" : "—")
            if !note.summaryModel.isEmpty {
                runRow("Models", "\(note.transcriptionModel) · \(note.summaryModel)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(Rectangle().strokeBorder(Theme.divider, lineWidth: 1))
        .blueprintCorners()
    }

    private func runRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Theme.body(12))
                .foregroundStyle(Theme.ink(0.55))
            Spacer(minLength: 12)
            Text(value)
                .font(Theme.head(15))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        Text(note.transcript.isEmpty ? "No transcript." : note.transcript)
            .font(Theme.body(14))
            .lineSpacing(6)
            .foregroundStyle(note.transcript.isEmpty ? Theme.ink(0.5) : Theme.text)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var stamp: String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(note.createdAt) { day = "Today" }
        else if calendar.isDateInYesterday(note.createdAt) { day = "Yesterday" }
        else { day = note.createdAt.formatted(.dateTime.month().day()) }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "\(day) · \(f.string(from: note.createdAt))"
    }
}

/// One tappable action item with a squared checkbox.
private struct ActionItemRow: View {
    @Bindable var item: ActionItem

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { item.done.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 13) {
                if item.done {
                    Rectangle().fill(Theme.accent).frame(width: 20, height: 20)
                        .overlay(Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.bg))
                        .padding(.top, 1)
                } else {
                    Rectangle().strokeBorder(Theme.ink(0.4), lineWidth: 1).frame(width: 20, height: 20)
                        .padding(.top, 1)
                }
                Text(item.text)
                    .font(Theme.body(14))
                    .lineSpacing(3)
                    .strikethrough(item.done, color: Theme.ink(0.45))
                    .foregroundStyle(item.done ? Theme.ink(0.45) : Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink(0.08)).frame(height: 1) }
    }
}

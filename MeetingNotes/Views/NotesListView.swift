import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// Home screen (design 1a): capture log grouped by day, with Record and Import.
struct NotesListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    @State private var path: [Note] = []
    @State private var showingCapture = false
    @State private var captureStage: CaptureStage = .recording
    @State private var showingImporter = false
    @State private var showingImportOptions = false
    @State private var showingPhotosPicker = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var showingSettings = false
    @State private var showingUsage = false
    @State private var errorMessage: String?

    private enum CaptureStage {
        case recording
        case processing(ProcessingInput)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header
                countRow
                Rectangle().fill(Theme.divider).frame(height: 1)
                content
                captureBar
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Note.self) { NoteDetailView(note: $0) }
        }
        .tint(Theme.accent)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingUsage) {
            UsageView()
        }
        .fullScreenCover(isPresented: $showingCapture) {
            switch captureStage {
            case .recording:
                RecordingView { recordedURL in
                    if let recordedURL {
                        captureStage = .processing(.recordedAudio(recordedURL))
                    } else {
                        showingCapture = false
                    }
                }
            case .processing(let input):
                ProcessingView(input: input) { processed in
                    let note = makeNote(from: processed)
                    context.insert(note)
                    showingCapture = false
                    path.append(note)
                } onCancel: {
                    showingCapture = false
                }
            }
        }
        .sheet(isPresented: $showingImportOptions) {
            ImportSheet(
                onPhotos: { showingImportOptions = false; showingPhotosPicker = true },
                onFiles: { showingImportOptions = false; showingImporter = true }
            )
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.hidden)
        }
        .photosPicker(isPresented: $showingPhotosPicker, selection: $pickedItem, matching: .videos)
        .onChange(of: pickedItem) { _, newItem in
            guard let newItem else { return }
            captureStage = .processing(.photosItem(newItem))
            showingCapture = true
            pickedItem = nil
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.movie, .audio, .mpeg4Movie, .mpeg4Audio],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Local · no account")
                Text("Notes")
                    .font(Theme.head(36))
                    .tracking(-0.36)
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            HStack(spacing: 8) {
                headerIcon("chart.bar") { showingUsage = true }
                headerIcon("slider.horizontal.3") { showingSettings = true }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func headerIcon(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.text)
                .frame(width: 38, height: 38)
                .overlay(Rectangle().strokeBorder(Theme.divider, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private var countRow: some View {
        HStack {
            Eyebrow(text: "\(notes.count) notes", size: 10, em: 0.14, color: Theme.ink(0.5))
            Spacer()
            Eyebrow(text: "\(totalOpen) open actions", size: 10, em: 0.14, color: Theme.ink(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        if notes.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    ForEach(groupedSections) { section in
                        groupHeader(section.title)
                        ForEach(section.notes) { entry in
                            NoteRowView(entry: entry) { path.append(entry.note) }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        context.delete(entry.note)
                                    } label: { Label("Delete note", systemImage: "trash") }
                                }
                        }
                    }
                    Color.clear.frame(height: 24)
                }
            }
        }
    }

    private func groupHeader(_ title: String) -> some View {
        HStack(spacing: 10) {
            Eyebrow(text: title, size: 11, em: 0.16, color: Theme.accent700, heading: true)
            Rectangle().fill(Theme.divider).frame(height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "waveform")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Theme.accent)
                .frame(width: 64, height: 64)
                .blueprintCorners(color: Theme.ink(0.4), out: 5)
                .padding(.bottom, 22)
            Text("Nothing captured yet")
                .font(Theme.head(26))
                .foregroundStyle(Theme.text)
                .padding(.bottom, 8)
            Text("Record a conversation or import a file. You get a transcript, a summary and action items — processed with your own key, kept on this device.")
                .font(Theme.body(13.5))
                .foregroundStyle(Theme.ink(0.6))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Capture bar

    private var captureBar: some View {
        HStack(spacing: 10) {
            Button { startImport() } label: {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.text)
                    .frame(width: 52, height: 52)
                    .overlay(Rectangle().strokeBorder(Theme.divider, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())

            Button { startRecording() } label: {
                HStack(spacing: 9) {
                    Image(systemName: "mic")
                        .font(.system(size: 17, weight: .regular))
                    Text("RECORD")
                        .font(Theme.head(15))
                        .tracking(1.8)
                }
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.accent)
                .overlay(Rectangle().strokeBorder(Theme.accent, lineWidth: 1))
                .blueprintCorners(color: Theme.ink(0.5))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(Theme.bg)
        .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
    }

    // MARK: - Grouping

    struct NoteEntry: Identifiable {
        let note: Note
        let index: Int       // capture number (descending)
        var id: UUID { note.id }
    }

    private struct DaySection: Identifiable {
        let id: Date
        let title: String
        let notes: [NoteEntry]
    }

    private var totalOpen: Int { notes.reduce(0) { $0 + $1.openCount } }

    private var groupedSections: [DaySection] {
        let calendar = Calendar.current
        let entries = notes.enumerated().map { NoteEntry(note: $1, index: notes.count - $0) }
        let groups = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.note.createdAt) }
        return groups.keys.sorted(by: >).map { day in
            DaySection(id: day, title: header(for: day),
                       notes: groups[day]?.sorted { $0.note.createdAt > $1.note.createdAt } ?? [])
        }
    }

    private func header(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        if let days = calendar.dateComponents([.day], from: day, to: .now).day, days < 7 {
            return day.formatted(.dateTime.weekday(.wide))
        }
        return day.formatted(.dateTime.month().day().year())
    }

    // MARK: - Actions

    private func startRecording() {
        guard requireKey() else { return }
        captureStage = .recording
        showingCapture = true
    }

    private func startImport() {
        guard requireKey() else { return }
        showingImportOptions = true
    }

    private func requireKey() -> Bool {
        if settings.isConfigured { return true }
        showingSettings = true
        return false
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            captureStage = .processing(.importedFile(url))
            showingCapture = true
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func makeNote(from processed: ProcessedNote) -> Note {
        let note = Note(
            title: processed.summary.title,
            transcript: processed.transcript,
            summary: processed.summary.summary,
            duration: processed.duration,
            actionItems: processed.summary.actionItems.map { ActionItem(text: $0) }
        )
        note.transcriptionLatency = processed.transcriptionLatency
        note.summaryLatency = processed.summaryLatency
        note.promptTokens = processed.promptTokens
        note.completionTokens = processed.completionTokens
        note.estimatedCost = processed.estimatedCost
        note.transcriptionModel = processed.transcriptionModel
        note.summaryModel = processed.summaryModel
        return note
    }
}

/// One capture-log row: index, title, time, preview, duration + open tags.
private struct NoteRowView: View {
    let entry: NotesListView.NoteEntry
    let onTap: () -> Void

    private var note: Note { entry.note }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(String(format: "%02d", entry.index))
                        .font(Theme.body(11))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink(0.45))
                        .frame(width: 22, alignment: .leading)
                    Text(note.title)
                        .font(Theme.head(20))
                        .tracking(-0.1)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(timeString(note.createdAt))
                        .font(Theme.body(11))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink(0.5))
                }
                if !note.summary.isEmpty {
                    HStack(spacing: 12) {
                        Color.clear.frame(width: 22, height: 0)
                        Text(note.summary)
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.ink(0.62))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                HStack(spacing: 8) {
                    if note.duration > 0 {
                        Tag(text: note.durationText, kind: .neutral)
                    }
                    if note.openCount > 0 {
                        Tag(text: "\(note.openCount) open", kind: .outline)
                    }
                }
                .padding(.leading, 34)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.ink(0.08)).frame(height: 1)
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

/// Bottom sheet offering Photos or Files import.
private struct ImportSheet: View {
    let onPhotos: () -> Void
    let onFiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Import audio or video")
                .font(Theme.head(22))
                .foregroundStyle(Theme.text)
                .padding(.bottom, 4)
            Text("Video files have their audio extracted first. Nothing leaves the device except the audio you send to your own key.")
                .font(Theme.body(12.5))
                .foregroundStyle(Theme.ink(0.58))
                .lineSpacing(2)
                .padding(.bottom, 16)
            sheetButton(icon: "photo", label: "Photos library", action: onPhotos)
                .padding(.bottom, 10)
            sheetButton(icon: "folder", label: "Files", action: onFiles)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg)
    }

    private func sheetButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .regular))
                Text(label.uppercased())
                    .font(Theme.head(15))
                    .tracking(0.9)
                Spacer()
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .overlay(Rectangle().strokeBorder(Theme.divider, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

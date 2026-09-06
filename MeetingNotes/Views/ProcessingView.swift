import SwiftUI
import PhotosUI

/// The audio source being turned into a note.
enum ProcessingInput: Identifiable {
    case recordedAudio(URL)
    case importedFile(URL)
    case photosItem(PhotosPickerItem)

    var id: String {
        switch self {
        case .recordedAudio(let url): return "rec-\(url.absoluteString)"
        case .importedFile(let url): return "imp-\(url.absoluteString)"
        case .photosItem(let item): return "pho-\(item.itemIdentifier ?? UUID().uuidString)"
        }
    }

    var isRecording: Bool {
        if case .recordedAudio = self { return true }
        return false
    }
}

/// Runs normalization (if needed), transcription, and summarization, showing a
/// blueprint stepper. Calls `onComplete`, or shows an error with a way out.
struct ProcessingView: View {
    let input: ProcessingInput
    let onComplete: (ProcessedNote) -> Void
    let onCancel: () -> Void

    @Environment(AppSettings.self) private var settings

    @State private var processor: NoteProcessor?
    @State private var errorMessage: String?
    @State private var didRun = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if let errorMessage {
                errorView(errorMessage)
            } else {
                progressView
            }
        }
        .interactiveDismissDisabled(errorMessage == nil)
        .task {
            guard !didRun else { return }
            didRun = true
            await run()
        }
    }

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: sourceLabel)
            Text("Creating note")
                .font(Theme.head(34))
                .foregroundStyle(Theme.text)
                .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(steps.indices, id: \.self) { i in
                    stepRow(steps[i], isLast: i == steps.count - 1)
                }
            }
            .padding(.top, 36)

            Spacer(minLength: 0)

            Rectangle().fill(Theme.divider).frame(height: 1).padding(.bottom, 14)
            HStack {
                Eyebrow(text: "Your key · your account", size: 10, em: 0.14, color: Theme.ink(0.5))
                Spacer()
                Eyebrow(text: stageLabel, size: 10, em: 0.14, color: Theme.accent700)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 24)
    }

    private func stepRow(_ step: Step, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                indicator(step.state)
                if !isLast {
                    Rectangle().fill(Theme.divider)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(step.n)
                        .font(Theme.body(11))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink(0.45))
                    Text(step.title)
                        .font(Theme.head(21))
                        .foregroundStyle(Theme.text)
                }
                Text(step.note)
                    .font(Theme.body(12.5))
                    .foregroundStyle(Theme.ink(0.58))
                    .lineSpacing(2)
            }
            .padding(.bottom, 26)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func indicator(_ state: StepState) -> some View {
        switch state {
        case .done:
            Rectangle().fill(Theme.accent).frame(width: 26, height: 26)
                .overlay(Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.bg))
        case .active:
            RingSpinner().frame(width: 26, height: 26)
        case .pending:
            Rectangle().strokeBorder(Theme.divider, lineWidth: 1).frame(width: 26, height: 26)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text("Couldn't create note")
                .font(Theme.head(28))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Text(message)
                .font(Theme.body(13.5))
                .foregroundStyle(Theme.ink(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button { onCancel() } label: {
                Text("CLOSE")
                    .font(Theme.head(14))
                    .tracking(1.4)
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 40)
                    .frame(height: 48)
                    .background(Theme.accent)
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 8)
        }
        .padding(40)
    }

    // MARK: - Steps

    private struct Step { let n: String; let title: String; let note: String; let state: StepState }

    private var steps: [Step] {
        let stage = processor?.stage
        let prep: StepState = stage == nil ? .active : .done
        let trans: StepState = stage == .transcribing ? .active : (stage == .summarizing ? .done : .pending)
        let summ: StepState = stage == .summarizing ? .active : .pending
        return [
            Step(n: "01", title: prepTitle, note: prepNote, state: prep),
            Step(n: "02", title: "Transcribing",
                 note: "Sent to your transcription model. Nothing is stored on our side.", state: trans),
            Step(n: "03", title: "Summarizing",
                 note: "Returning a title, a summary and the action items.", state: summ),
        ]
    }

    private var prepTitle: String { input.isRecording ? "Preparing audio" : "Extracting audio" }
    private var prepNote: String {
        input.isRecording
            ? "Normalising levels and writing the file locally."
            : "Pulling the audio track out of the selected file."
    }
    private var sourceLabel: String { input.isRecording ? "From recording" : "From imported file" }
    private var stageLabel: String {
        switch processor?.stage {
        case .transcribing: return "Transcribing"
        case .summarizing: return "Summarizing"
        case nil: return "Preparing"
        }
    }

    // MARK: - Pipeline

    private func run() async {
        do {
            let audioURL = try await resolveAudioURL()
            let processor = NoteProcessor(settings: settings)
            self.processor = processor
            let processed = try await processor.process(audioURL: audioURL)
            onComplete(processed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveAudioURL() async throws -> URL {
        switch input {
        case .recordedAudio(let url):
            return url
        case .importedFile(let source):
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            return try await AudioNormalizer.normalize(sourceURL: source)
        case .photosItem(let item):
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                throw NSError(domain: "Import", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Couldn't load that video from Photos."])
            }
            // We copied the video into tmp to load it; delete that copy once the
            // audio has been extracted so no video lingers on disk.
            defer { try? FileManager.default.removeItem(at: movie.url) }
            return try await AudioNormalizer.normalize(sourceURL: movie.url)
        }
    }
}

/// Visual state of one step in the processing pipeline.
enum StepState { case pending, active, done }

/// A thin rotating ring used for the active step.
private struct RingSpinner: View {
    @State private var spin = false
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.72)
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .butt))
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: spin)
            .onAppear { spin = true }
    }
}

import Foundation
import Observation
import AVFoundation

/// Stages shown while a note is being produced.
enum ProcessingStage: Equatable {
    case transcribing
    case summarizing

    var label: String {
        switch self {
        case .transcribing: return "Transcribing…"
        case .summarizing: return "Summarizing…"
        }
    }
}

/// The finished pieces of a note, before it is saved to SwiftData.
struct ProcessedNote {
    let transcript: String
    let summary: SummaryResult
    let duration: TimeInterval
}

/// Orchestrates the transcribe → summarize pipeline for one audio file and
/// exposes the current stage for the UI. Always deletes the (temporary) input
/// file when finished.
@Observable
@MainActor
final class NoteProcessor {
    private(set) var stage: ProcessingStage = .transcribing

    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// Transcribes and summarizes `audioURL`. The file is deleted before returning.
    /// - Throws: `OpenAIError` (or a normalization/audio error) on failure.
    func process(audioURL: URL) async throws -> ProcessedNote {
        defer { try? FileManager.default.removeItem(at: audioURL) }

        guard !settings.transcriptionKey.isEmpty, !settings.summaryKey.isEmpty else {
            throw OpenAIError.missingKey
        }

        // Read the clip length before uploading (best-effort).
        let duration = (try? await AVURLAsset(url: audioURL).load(.duration).seconds) ?? 0

        stage = .transcribing
        let transcription = TranscriptionService(
            apiKey: settings.transcriptionKey,
            baseURL: settings.transcriptionBaseURL,
            model: settings.transcriptionModel
        )
        let transcript = try await transcription.transcribe(fileURL: audioURL)

        stage = .summarizing
        let summarizer = SummaryService(
            apiKey: settings.summaryKey,
            baseURL: settings.summaryBaseURL,
            model: settings.summaryModel
        )
        let summary = try await summarizer.summarize(transcript: transcript)

        return ProcessedNote(transcript: transcript, summary: summary,
                             duration: duration.isFinite ? duration : 0)
    }
}

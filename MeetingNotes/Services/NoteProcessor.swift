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
    // Run metrics
    let transcriptionLatency: TimeInterval
    let summaryLatency: TimeInterval
    let promptTokens: Int
    let completionTokens: Int
    let estimatedCost: Double
    let transcriptionModel: String
    let summaryModel: String
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
        let rawDuration = (try? await AVURLAsset(url: audioURL).load(.duration).seconds) ?? 0
        let duration = rawDuration.isFinite ? rawDuration : 0

        let transcriptionModel = settings.transcriptionModel
        let summaryModel = settings.summaryModel

        stage = .transcribing
        let transcription = TranscriptionService(
            apiKey: settings.transcriptionKey,
            baseURL: settings.transcriptionBaseURL,
            model: transcriptionModel
        )
        let transcribeStart = Date()
        let transcript = try await transcription.transcribe(fileURL: audioURL)
        let transcriptionLatency = Date().timeIntervalSince(transcribeStart)

        stage = .summarizing
        let summarizer = SummaryService(
            apiKey: settings.summaryKey,
            baseURL: settings.summaryBaseURL,
            model: summaryModel
        )
        let summarizeStart = Date()
        let output = try await summarizer.summarize(transcript: transcript)
        let summaryLatency = Date().timeIntervalSince(summarizeStart)

        // Estimate cost from what we know (0 for the parts of unknown models).
        let transcriptionCost = Pricing.transcriptionCost(model: transcriptionModel, seconds: duration) ?? 0
        let summaryCost = Pricing.summaryCost(
            model: summaryModel,
            promptTokens: output.promptTokens,
            completionTokens: output.completionTokens
        ) ?? 0

        return ProcessedNote(
            transcript: transcript,
            summary: output.result,
            duration: duration,
            transcriptionLatency: transcriptionLatency,
            summaryLatency: summaryLatency,
            promptTokens: output.promptTokens,
            completionTokens: output.completionTokens,
            estimatedCost: transcriptionCost + summaryCost,
            transcriptionModel: transcriptionModel,
            summaryModel: summaryModel
        )
    }
}

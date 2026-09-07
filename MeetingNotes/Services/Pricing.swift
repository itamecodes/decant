import Foundation

/// Rough, local cost estimates for known models. Everything here is an
/// approximation — provider prices change, and transcription is billed per
/// minute of audio. Unknown models return `nil` (cost shown as unavailable).
enum Pricing {
    /// USD per 1M tokens (input, output) for chat/summary models.
    static let chat: [String: (input: Double, output: Double)] = [
        "gpt-4o-mini": (0.15, 0.60),
        "gpt-4o": (2.50, 10.00),
        "deepseek-chat": (0.27, 1.10),
        "deepseek-reasoner": (0.55, 2.19),
        "llama-3.3-70b-versatile": (0.59, 0.79),
        "llama-3.1-8b-instant": (0.05, 0.08),
    ]

    /// USD per minute of audio for transcription models.
    static let transcriptionPerMinute: [String: Double] = [
        "gpt-4o-mini-transcribe": 0.003,
        "gpt-4o-transcribe": 0.006,
        "whisper-1": 0.006,
        "whisper-large-v3-turbo": 0.04 / 60,
        "whisper-large-v3": 0.111 / 60,
    ]

    /// Estimated summary cost from token usage, or `nil` for an unknown model.
    static func summaryCost(model: String, promptTokens: Int, completionTokens: Int) -> Double? {
        guard let rate = match(model, in: Array(chat.keys)).flatMap({ chat[$0] }) else { return nil }
        return Double(promptTokens) / 1_000_000 * rate.input
            + Double(completionTokens) / 1_000_000 * rate.output
    }

    /// Estimated transcription cost from audio length, or `nil` for an unknown model.
    static func transcriptionCost(model: String, seconds: TimeInterval) -> Double? {
        guard let perMinute = match(model, in: Array(transcriptionPerMinute.keys))
            .flatMap({ transcriptionPerMinute[$0] }) else { return nil }
        return seconds / 60 * perMinute
    }

    /// Finds the most specific known key contained in `model` (longest match wins,
    /// so "gpt-4o-mini" beats "gpt-4o").
    private static func match(_ model: String, in keys: [String]) -> String? {
        let lower = model.lowercased()
        return keys
            .filter { lower.contains($0.lowercased()) }
            .max(by: { $0.count < $1.count })
    }
}

import Foundation

/// Builds request URLs for any OpenAI-compatible provider from its base URL.
enum OpenAICompatible {
    /// Joins a base URL (e.g. `https://api.groq.com/openai/v1`) with a path
    /// (e.g. `chat/completions`), tolerating a trailing slash on the base.
    static func endpoint(_ baseURL: String, _ path: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let base = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return URL(string: "\(base)/\(path)")
    }
}

/// Errors surfaced from provider network calls, with user-presentable messages.
enum OpenAIError: LocalizedError {
    case missingKey
    case fileTooLarge(bytes: Int)
    case http(status: Int, message: String)
    case invalidResponse
    case network(underlying: Error)

    /// The common OpenAI-compatible cap on audio uploads (Whisper endpoints).
    static let maxUploadBytes = 25 * 1024 * 1024

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "No API key set for this provider. Add one in Settings."
        case .fileTooLarge(let bytes):
            let mb = Double(bytes) / 1_048_576
            return String(format: "Recording is too large to transcribe (%.1f MB, limit 25 MB). Try a shorter recording.", mb)
        case .http(let status, let message):
            return "Provider error (\(status)): \(message)"
        case .invalidResponse:
            return "Received an unexpected response from the provider."
        case .network(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        }
    }
}

/// Shape of OpenAI's JSON error envelope: `{ "error": { "message": ... } }`.
struct OpenAIErrorEnvelope: Decodable {
    struct Inner: Decodable { let message: String }
    let error: Inner
}

enum OpenAIResponseParser {
    /// Extracts a human-readable message from an error response body, falling back to raw text.
    static func errorMessage(from data: Data) -> String {
        if let envelope = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data) {
            return envelope.error.message
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}

import Foundation
import Observation

/// A one-tap preset for an OpenAI-compatible provider.
struct ProviderPreset: Identifiable, Hashable {
    let name: String
    let baseURL: String
    let model: String
    var id: String { name }
}

/// App-wide configuration. Transcription and summary are configured independently
/// — each is any OpenAI-compatible endpoint (base URL + key + model) — because
/// not every provider offers audio transcription. Keys live in the Keychain;
/// base URLs and model names in UserDefaults.
@Observable
final class AppSettings {
    private let transcriptionKeyAccount = "transcription_key"
    private let summaryKeyAccount = "summary_key"
    private let legacyKeyAccount = "openai_api_key"

    /// Providers that expose an OpenAI-style `/audio/transcriptions` endpoint.
    static let transcriptionPresets: [ProviderPreset] = [
        ProviderPreset(name: "OpenAI", baseURL: "https://api.openai.com/v1", model: "gpt-4o-transcribe"),
        ProviderPreset(name: "Groq", baseURL: "https://api.groq.com/openai/v1", model: "whisper-large-v3"),
    ]

    /// Providers that speak OpenAI-style `/chat/completions`.
    static let summaryPresets: [ProviderPreset] = [
        ProviderPreset(name: "OpenAI", baseURL: "https://api.openai.com/v1", model: "gpt-4o"),
        ProviderPreset(name: "Groq", baseURL: "https://api.groq.com/openai/v1", model: "llama-3.3-70b-versatile"),
        ProviderPreset(name: "DeepSeek", baseURL: "https://api.deepseek.com/v1", model: "deepseek-chat"),
        ProviderPreset(name: "Qwen", baseURL: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1", model: "qwen-plus"),
        ProviderPreset(name: "OpenRouter", baseURL: "https://openrouter.ai/api/v1", model: "meta-llama/llama-3.3-70b-instruct"),
        ProviderPreset(name: "Together", baseURL: "https://api.together.xyz/v1", model: "meta-llama/Llama-3.3-70B-Instruct-Turbo"),
    ]

    static var defaultTranscription: ProviderPreset { transcriptionPresets[0] }
    static var defaultSummary: ProviderPreset { summaryPresets[0] }

    // Transcription endpoint
    var transcriptionBaseURL: String { didSet { UserDefaults.standard.set(transcriptionBaseURL, forKey: "transcriptionBaseURL") } }
    var transcriptionModel: String { didSet { UserDefaults.standard.set(transcriptionModel, forKey: "transcriptionModel") } }
    var transcriptionKey: String { didSet { KeychainStore.set(transcriptionKey, account: transcriptionKeyAccount) } }

    // Summary endpoint
    var summaryBaseURL: String { didSet { UserDefaults.standard.set(summaryBaseURL, forKey: "summaryBaseURL") } }
    var summaryModel: String { didSet { UserDefaults.standard.set(summaryModel, forKey: "summaryModel") } }
    var summaryKey: String { didSet { KeychainStore.set(summaryKey, account: summaryKeyAccount) } }

    init() {
        let defaults = UserDefaults.standard
        // Migrate the old single-key, OpenAI-only setup: reuse that key for both
        // endpoints when the per-endpoint keys aren't set yet.
        let legacyKey = KeychainStore.get(account: legacyKeyAccount)

        _transcriptionKey = KeychainStore.get(account: transcriptionKeyAccount) ?? legacyKey ?? ""
        _summaryKey = KeychainStore.get(account: summaryKeyAccount) ?? legacyKey ?? ""
        _transcriptionBaseURL = defaults.string(forKey: "transcriptionBaseURL") ?? AppSettings.defaultTranscription.baseURL
        _summaryBaseURL = defaults.string(forKey: "summaryBaseURL") ?? AppSettings.defaultSummary.baseURL
        _transcriptionModel = defaults.string(forKey: "transcriptionModel") ?? AppSettings.defaultTranscription.model
        _summaryModel = defaults.string(forKey: "summaryModel") ?? AppSettings.defaultSummary.model
    }

    /// True once both endpoints have a key; the app can't produce a note without both.
    var isConfigured: Bool {
        !transcriptionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !summaryKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Fill the transcription endpoint from a preset (key is left as-is).
    func applyTranscriptionPreset(_ preset: ProviderPreset) {
        transcriptionBaseURL = preset.baseURL
        transcriptionModel = preset.model
    }

    /// Fill the summary endpoint from a preset (key is left as-is).
    func applySummaryPreset(_ preset: ProviderPreset) {
        summaryBaseURL = preset.baseURL
        summaryModel = preset.model
    }
}

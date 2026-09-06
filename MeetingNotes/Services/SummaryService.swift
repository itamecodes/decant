import Foundation

/// The structured result of summarizing a transcript.
struct SummaryResult: Decodable {
    let title: String
    let summary: String
    let actionItems: [String]
}

/// Generates a title, summary, and action items from a transcript via any
/// OpenAI-compatible Chat Completions endpoint. Uses JSON-object mode with an
/// explicitly described shape and lenient parsing, so it works across providers
/// (OpenAI, Groq, DeepSeek, Qwen, OpenRouter, …) that vary in schema support.
struct SummaryService {
    let apiKey: String
    let baseURL: String
    let model: String
    let session: URLSession

    init(apiKey: String, baseURL: String, model: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.session = session
    }

    func summarize(transcript: String) async throws -> SummaryResult {
        guard !apiKey.isEmpty else { throw OpenAIError.missingKey }
        guard let url = OpenAICompatible.endpoint(baseURL, "chat/completions") else {
            throw OpenAIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(transcript: transcript))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenAIError.network(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else { throw OpenAIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw OpenAIError.http(status: http.statusCode, message: OpenAIResponseParser.errorMessage(from: data))
        }

        return try Self.parse(data: data)
    }

    /// The Chat Completions payload. `json_object` mode is far more widely
    /// supported than `json_schema`; the exact shape is spelled out in the prompt.
    private func requestBody(transcript: String) -> [String: Any] {
        [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You summarize meeting and conversation transcripts. Respond with ONLY a \
                    JSON object — no markdown, no commentary — with exactly these keys:
                    - "title": a concise title, a few words.
                    - "summary": a clear prose summary of the key points and decisions.
                    - "actionItems": an array of strings, one concrete action item each \
                    (an empty array if there are none).
                    Base everything only on the transcript.
                    """,
                ],
                [
                    "role": "user",
                    "content": transcript,
                ],
            ],
            "response_format": ["type": "json_object"],
        ]
    }

    /// Extracts the assistant message and decodes the JSON object it contains,
    /// tolerating code fences or stray prose around it.
    static func parse(data: Data) throws -> SummaryResult {
        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }

        guard
            let chat = try? JSONDecoder().decode(ChatResponse.self, from: data),
            let content = chat.choices.first?.message.content,
            let json = extractJSONObject(from: content),
            let result = try? JSONDecoder().decode(SummaryResult.self, from: Data(json.utf8))
        else {
            throw OpenAIError.invalidResponse
        }
        return result
    }

    /// Returns the outermost `{ … }` object in a string, stripping any code
    /// fences or surrounding text a chattier model may add.
    static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start < end
        else { return nil }
        return String(text[start...end])
    }
}

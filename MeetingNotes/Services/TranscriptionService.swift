import Foundation

/// Transcribes an audio file via OpenAI's `/v1/audio/transcriptions` endpoint.
struct TranscriptionService {
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

    /// Uploads `fileURL` and returns the transcript text.
    /// - Throws: `OpenAIError` for missing key, oversized file, HTTP, or network failures.
    func transcribe(fileURL: URL) async throws -> String {
        guard !apiKey.isEmpty else { throw OpenAIError.missingKey }

        let audioData = try Data(contentsOf: fileURL)
        guard audioData.count <= OpenAIError.maxUploadBytes else {
            throw OpenAIError.fileTooLarge(bytes: audioData.count)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = OpenAICompatible.endpoint(baseURL, "audio/transcriptions") else {
            throw OpenAIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(
            boundary: boundary,
            model: model,
            fileURL: fileURL,
            audioData: audioData
        )

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

        // Default response_format is JSON: `{ "text": "..." }`.
        struct TranscriptionResponse: Decodable { let text: String }
        guard let decoded = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) else {
            throw OpenAIError.invalidResponse
        }
        return decoded.text
    }

    /// Builds a multipart/form-data body with the `model` field and the audio file.
    static func multipartBody(boundary: String, model: String, fileURL: URL, audioData: Data) -> Data {
        var body = Data()
        let filename = fileURL.lastPathComponent
        let mimeType = Self.mimeType(for: fileURL.pathExtension)

        func append(_ string: String) { body.append(string.data(using: .utf8)!) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("\(model)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(audioData)
        append("\r\n")

        append("--\(boundary)--\r\n")
        return body
    }

    static func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "m4a": return "audio/m4a"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "mp4": return "audio/mp4"
        case "webm": return "audio/webm"
        case "ogg": return "audio/ogg"
        case "flac": return "audio/flac"
        default: return "application/octet-stream"
        }
    }
}

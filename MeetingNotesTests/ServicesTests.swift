import XCTest
@testable import MeetingNotes

final class ServicesTests: XCTestCase {

    func testEndpointBuilderToleratesTrailingSlash() {
        XCTAssertEqual(
            OpenAICompatible.endpoint("https://api.groq.com/openai/v1", "chat/completions")?.absoluteString,
            "https://api.groq.com/openai/v1/chat/completions"
        )
        XCTAssertEqual(
            OpenAICompatible.endpoint("https://api.openai.com/v1/", "audio/transcriptions")?.absoluteString,
            "https://api.openai.com/v1/audio/transcriptions"
        )
        XCTAssertNil(OpenAICompatible.endpoint("   ", "chat/completions"))
    }

    func testSummaryParsingToleratesCodeFencesAndProse() throws {
        // A chattier open model may wrap JSON in a ```json fence with commentary.
        let inner = "Sure! Here you go:\\n```json\\n{\\\"title\\\":\\\"Standup\\\",\\\"summary\\\":\\\"Shipped.\\\",\\\"actionItems\\\":[]}\\n```"
        let payload = "{\"choices\":[{\"message\":{\"content\":\"\(inner)\"}}]}"
        let result = try SummaryService.parse(data: Data(payload.utf8))
        XCTAssertEqual(result.title, "Standup")
        XCTAssertEqual(result.summary, "Shipped.")
        XCTAssertTrue(result.actionItems.isEmpty)
    }

    func testSummaryParsingExtractsStructuredContent() throws {
        // Chat Completions returns the JSON payload as a string in message.content.
        let inner = """
        {"title":"Sync","summary":"We agreed on scope.","actionItems":["Email the deck","Book a room"]}
        """
        let payload = """
        {"choices":[{"message":{"role":"assistant","content":\(inner.debugQuoted)}}]}
        """
        let data = Data(payload.utf8)

        let result = try SummaryService.parse(data: data)

        XCTAssertEqual(result.title, "Sync")
        XCTAssertEqual(result.summary, "We agreed on scope.")
        XCTAssertEqual(result.actionItems, ["Email the deck", "Book a room"])
    }

    func testSummaryParsingThrowsOnMissingChoices() {
        let data = Data("{\"choices\":[]}".utf8)
        XCTAssertThrowsError(try SummaryService.parse(data: data))
    }

    func testMultipartBodyIncludesModelAndFile() {
        let audio = Data("fake-audio".utf8)
        let url = URL(fileURLWithPath: "/tmp/clip.m4a")
        let body = TranscriptionService.multipartBody(
            boundary: "B", model: "gpt-4o-transcribe", fileURL: url, audioData: audio
        )
        let text = String(data: body, encoding: .utf8) ?? ""

        XCTAssertTrue(text.contains("name=\"model\""))
        XCTAssertTrue(text.contains("gpt-4o-transcribe"))
        XCTAssertTrue(text.contains("filename=\"clip.m4a\""))
        XCTAssertTrue(text.contains("Content-Type: audio/m4a"))
        XCTAssertTrue(text.contains("fake-audio"))
    }

    func testShareTextIncludesAllSections() {
        let note = Note(
            title: "Kickoff",
            transcript: "Hello everyone.",
            summary: "Project kickoff.",
            actionItems: [ActionItem(text: "Send agenda", done: true)]
        )
        let text = note.shareText

        XCTAssertTrue(text.contains("# Kickoff"))
        XCTAssertTrue(text.contains("## Summary"))
        XCTAssertTrue(text.contains("Project kickoff."))
        XCTAssertTrue(text.contains("[x] Send agenda"))
        XCTAssertTrue(text.contains("## Transcript"))
    }
}

private extension String {
    /// Encodes the string as a JSON string literal (including surrounding quotes).
    var debugQuoted: String {
        let data = try! JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8)!
    }
}

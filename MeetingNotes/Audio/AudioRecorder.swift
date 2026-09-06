import Foundation
import AVFoundation
import Observation

/// Records microphone audio to a compact mono m4a file using `AVAudioRecorder`.
///
/// Produces a file already small enough to upload directly, so recorded audio
/// needs no further normalization.
@Observable
@MainActor
final class AudioRecorder {
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var outputURL: URL?

    /// Asks for microphone permission. Returns whether it was granted.
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Begins recording to a fresh temp file. Throws if the session or recorder can't start.
    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        guard recorder.record() else {
            throw NSError(domain: "AudioRecorder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not start recording."])
        }

        self.recorder = recorder
        self.outputURL = url
        self.isRecording = true
        self.elapsed = 0
        startTimer()
    }

    /// Stops recording and returns the finished file URL.
    @discardableResult
    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        stopTimer()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return outputURL
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder else { return }
                self.elapsed = recorder.currentTime
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

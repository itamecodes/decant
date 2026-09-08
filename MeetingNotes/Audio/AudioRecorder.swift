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

    /// Number of bars in the live waveform.
    static let barCount = 42
    /// Recent mic levels (0…1, oldest → newest) driving the waveform. Flat when silent.
    private(set) var levels = [Double](repeating: 0, count: AudioRecorder.barCount)

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var outputURL: URL?
    private var smoothedLevel = 0.0

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
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw NSError(domain: "AudioRecorder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not start recording."])
        }

        self.recorder = recorder
        self.outputURL = url
        self.isRecording = true
        self.elapsed = 0
        self.smoothedLevel = 0
        self.levels = [Double](repeating: 0, count: Self.barCount)
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder else { return }
                self.elapsed = recorder.currentTime

                // Sample the mic level and push it into the rolling waveform buffer.
                recorder.updateMeters()
                let db = Double(recorder.averagePower(forChannel: 0))   // ~ -160…0 dB
                let floorDb = -55.0
                var level = db <= floorDb ? 0 : (db - floorDb) / -floorDb  // 0…1
                level = pow(min(max(level, 0), 1), 1.5)                    // quiet stays quiet
                self.smoothedLevel = max(level, self.smoothedLevel * 0.80) // fast attack, gentle decay

                var next = self.levels
                next.removeFirst()
                next.append(self.smoothedLevel)
                self.levels = next
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

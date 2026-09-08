import SwiftUI

/// Full-screen recording UI (design 1a). Requests mic permission, records, and
/// returns the finished audio file via `onFinish` (or `nil` if cancelled).
struct RecordingView: View {
    let onFinish: (URL?) -> Void

    @State private var recorder = AudioRecorder()
    @State private var permissionDenied = false
    @State private var startError: String?
    @State private var blip = false

    private var light: Color { Theme.bg }

    var body: some View {
        ZStack {
            Theme.accent900.ignoresSafeArea()

            if permissionDenied {
                infoView(title: "Microphone access needed",
                         message: "Enable microphone access in Settings to record audio.")
            } else if let startError {
                infoView(title: "Couldn't record", message: startError)
            } else {
                recordingView
            }
        }
        .task { await beginRecording() }
    }

    private var recordingView: some View {
        VStack(spacing: 0) {
            // Status row
            HStack(spacing: 9) {
                Rectangle()
                    .fill(Theme.accent300)
                    .frame(width: 8, height: 8)
                    .opacity(blip ? 1 : 0.25)
                    .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: blip)
                Eyebrow(text: "Recording", size: 11, em: 0.2, color: Theme.accent200, heading: true)
                Spacer()
                Eyebrow(text: "44.1 kHz · m4a", size: 11, em: 0.1, color: light.opacity(0.45))
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)

            Spacer()

            VStack(alignment: .leading, spacing: 0) {
                Text(timeString(recorder.elapsed))
                    .font(Theme.headLight(104))
                    .tracking(-2)
                    .monospacedDigit()
                    .foregroundStyle(light)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Rectangle().fill(light.opacity(0.25)).frame(height: 1)
                    .padding(.vertical, 24)

                WaveformView(levels: recorder.levels, color: Theme.accent300)
                    .frame(height: 88)

                HStack {
                    Eyebrow(text: "Input · built-in mic", size: 10, em: 0.14, color: light.opacity(0.45))
                    Spacer()
                    Eyebrow(text: "Audio stays on device until you stop", size: 10, em: 0.14, color: light.opacity(0.45))
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    let url = recorder.stop()
                    onFinish(url)
                } label: {
                    HStack(spacing: 10) {
                        Rectangle().fill(Theme.accent900).frame(width: 14, height: 14)
                        Text("STOP & PROCESS")
                            .font(Theme.head(15))
                            .tracking(1.8)
                    }
                    .foregroundStyle(Theme.accent900)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(light)
                    .blueprintCorners(color: light.opacity(0.5))
                }
                .buttonStyle(PressableStyle())
                .disabled(!recorder.isRecording)

                Button {
                    _ = recorder.stop().map { try? FileManager.default.removeItem(at: $0) }
                    onFinish(nil)
                } label: {
                    Text("DISCARD")
                        .font(Theme.head(13))
                        .tracking(1.3)
                        .foregroundStyle(light.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .overlay(Rectangle().strokeBorder(light.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func infoView(title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(Theme.head(28))
                .foregroundStyle(light)
                .multilineTextAlignment(.center)
            Text(message)
                .font(Theme.body(13.5))
                .foregroundStyle(light.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                onFinish(nil)
            } label: {
                Text("CLOSE")
                    .font(Theme.head(14))
                    .tracking(1.4)
                    .foregroundStyle(Theme.accent900)
                    .padding(.horizontal, 40)
                    .frame(height: 48)
                    .background(light)
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 8)
        }
    }

    private func beginRecording() async {
        let granted = await recorder.requestPermission()
        guard granted else { permissionDenied = true; return }
        do {
            try recorder.start()
            blip = true
        } catch {
            startError = error.localizedDescription
        }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

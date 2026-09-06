import SwiftUI

/// Provider + model settings (design 1a). Transcription and summary are each
/// any OpenAI-compatible endpoint, configured independently.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(Theme.head(28))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button { dismiss() } label: {
                    Text("DONE").font(Theme.head(12)).tracking(1.2)
                        .foregroundStyle(settings.isConfigured ? Theme.accent : Theme.ink(0.35))
                }
                .disabled(!settings.isConfigured)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.divider).frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EndpointSection(
                        title: "Transcription",
                        caption: "Turns audio into text. Needs a provider with a Whisper endpoint (OpenAI or Groq).",
                        presets: AppSettings.transcriptionPresets,
                        baseURL: $settings.transcriptionBaseURL,
                        model: $settings.transcriptionModel,
                        key: $settings.transcriptionKey
                    )
                    .padding(.bottom, 30)

                    EndpointSection(
                        title: "Summary",
                        caption: "Writes the summary + action items. Any OpenAI-compatible chat model.",
                        presets: AppSettings.summaryPresets,
                        baseURL: $settings.summaryBaseURL,
                        model: $settings.summaryModel,
                        key: $settings.summaryKey
                    )
                    .padding(.bottom, 24)

                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Theme.accent)
                        Text("Keys are held in the device Keychain. Never synced.")
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.ink(0.58))
                    }
                    .padding(.bottom, 28)

                    storageCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 44)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .tint(Theme.accent)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Storage", size: 10, em: 0.1, color: Theme.accent)
            Text("On this device only")
                .font(Theme.head(17))
                .foregroundStyle(Theme.text)
            Text("Notes stay on this device. Only the audio and transcript you send reach the provider you choose. No servers of ours, no account, no analytics.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.ink(0.8))
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(Rectangle().strokeBorder(Theme.divider, lineWidth: 1))
        .blueprintCorners()
    }
}

/// One configurable OpenAI-compatible endpoint: preset picker, base URL, model, key.
private struct EndpointSection: View {
    let title: String
    let caption: String
    let presets: [ProviderPreset]
    @Binding var baseURL: String
    @Binding var model: String
    @Binding var key: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: title, size: 11, em: 0.16, color: Theme.accent700, heading: true)
                Spacer()
                Menu {
                    ForEach(presets) { preset in
                        Button(preset.name) {
                            baseURL = preset.baseURL
                            model = preset.model
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text("PRESET").font(Theme.body(11)).tracking(1)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .overlay(Rectangle().strokeBorder(Theme.divider, lineWidth: 1))
                }
            }
            .padding(.bottom, 4)

            Text(caption)
                .font(Theme.body(12))
                .foregroundStyle(Theme.ink(0.55))
                .lineSpacing(1)
                .padding(.bottom, 12)

            label("Base URL")
            TextField("https://api.openai.com/v1", text: $baseURL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .industryField(height: 40)
                .padding(.bottom, 10)

            label("Model")
            TextField("model id", text: $model)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .industryField(height: 40)
                .padding(.bottom, 10)

            label("API key")
            SecureField("sk-…", text: $key)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .industryField(height: 44)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.body(12))
            .foregroundStyle(Theme.ink(0.7))
            .padding(.bottom, 5)
    }
}

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var clock: TrainingClock
    @AppStorage(AppStorageKeys.screenshotPreviewMode) private var screenshotPreviewMode = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $clock.soundEnabled) {
                    Label(String(localized: "settings.sound"), systemImage: clock.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "settings.volume"))
                        Spacer()
                        Text("\(Int(clock.cueVolume))")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $clock.cueVolume, in: 0...100, step: 1) {
                        Text(String(localized: "settings.volume"))
                    } minimumValueLabel: {
                        Image(systemName: "speaker.fill")
                    } maximumValueLabel: {
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    .disabled(!clock.soundEnabled)
                    .opacity(clock.soundEnabled ? 1 : 0.4)
                }
            } footer: {
                Text(String(localized: "settings.audio_footer"))
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Label(String(localized: "about.title"), systemImage: "info.circle")
                }
                ShareHelper.TextOrURLButton(url: AppConfig.marketingURL)
            }

            #if DEBUG
            Section {
                Toggle(String(localized: "settings.screenshot_preview"), isOn: $screenshotPreviewMode)

                if AppConfig.reviewPromptEnabled {
                    Button(String(localized: "settings.reset_review")) {
                        ReviewPrompt.resetCountersForDebug()
                        HapticFeedback.selection()
                    }
                }
            } footer: {
                Text(String(localized: "settings.debug_footer"))
            }
            #endif
        }
        .navigationTitle(String(localized: "settings.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

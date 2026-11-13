import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var clock: TrainingClock
    @ObservedObject private var language = AppLanguage.shared
    @AppStorage(AppStorageKeys.screenshotPreviewMode) private var screenshotPreviewMode = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $clock.soundEnabled) {
                    Label(L10n.t("settings.sound"), systemImage: clock.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.t("settings.volume"))
                        Spacer()
                        Text("\(Int(clock.cueVolume))")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $clock.cueVolume, in: 0...100, step: 1, onEditingChanged: { editing in
                        if !editing { clock.previewVolume() }
                    })
                    .accessibilityLabel(L10n.t("settings.volume"))
                    .disabled(!clock.soundEnabled)
                    .opacity(clock.soundEnabled ? 1 : 0.4)
                }
            } footer: {
                Text(L10n.t("settings.audio_footer"))
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Label(L10n.t("about.title"), systemImage: "info.circle")
                }
                ShareHelper.TextOrURLButton(url: AppConfig.marketingURL(for: language.code))
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
        .navigationTitle(L10n.t("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

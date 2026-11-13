import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var clock: TrainingClock
    @ObservedObject private var language = AppLanguage.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                audioSection
                generalSection
                languageSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(L10n.t("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .settingsScreenChrome()
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsChrome.Panel {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $clock.soundEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: clock.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.body.weight(.semibold))
                                .frame(width: 24)
                                .foregroundStyle(Palette.gold)
                            Text(L10n.t("settings.sound"))
                                .font(Palette.ui(16))
                        }
                    }
                    .tint(Palette.gold)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.t("settings.volume"))
                                .font(Palette.ui(16))
                            Spacer()
                            Text("\(Int(clock.cueVolume))")
                                .font(Palette.ui(15).monospacedDigit())
                                .foregroundStyle(Palette.ink.opacity(0.64))
                        }
                        Slider(value: $clock.cueVolume, in: 0...100, step: 1, onEditingChanged: { editing in
                            if !editing { clock.previewVolume() }
                        })
                        .tint(Palette.gold)
                        .accessibilityLabel(L10n.t("settings.volume"))
                        .disabled(!clock.soundEnabled)
                        .opacity(clock.soundEnabled ? 1 : 0.4)
                    }
                }
            }
            SettingsChrome.Footer(text: L10n.t("settings.audio_footer"))
        }
    }

    private var generalSection: some View {
        SettingsChrome.Panel {
            VStack(alignment: .leading, spacing: 16) {
                SettingsChrome.LinkRow(title: L10n.t("about.title"), systemImage: "info.circle") {
                    AboutView()
                }
                Divider().overlay(Palette.gold.opacity(0.2))
                SettingsChrome.ShareRow(url: AppConfig.marketingURL(for: language.code))
            }
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("settings.language"))
                .font(Palette.ui(13, weight: .medium))
                .foregroundStyle(Palette.ink.opacity(0.55))
                .padding(.horizontal, 4)

            SettingsChrome.Panel {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsChrome.LanguagePicker(language: language)
                    if language.usesManualLanguage {
                        Button {
                            language.followSystemLanguage()
                            HapticFeedback.selection()
                        } label: {
                            Text(L10n.t("settings.language_system"))
                                .font(Palette.ui(15))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Palette.background.opacity(0.55), in: Capsule())
                                .overlay(Capsule().stroke(Palette.gold.opacity(0.24), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            SettingsChrome.Footer(text: L10n.t("settings.language_footer"))
        }
    }
}

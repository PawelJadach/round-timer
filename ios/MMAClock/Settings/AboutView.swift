import SwiftUI

struct AboutView: View {
    @ObservedObject private var language = AppLanguage.shared

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsChrome.Panel {
                    VStack(spacing: 12) {
                        infoRow(L10n.t("about.app"), value: AppConfig.displayName)
                        infoRow(L10n.t("about.version"), value: version)
                        infoRow(L10n.t("about.build"), value: build)
                    }
                }

                SettingsChrome.Panel {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsChrome.URLRow(
                            title: L10n.t("about.privacy"),
                            systemImage: "hand.raised",
                            url: AppConfig.privacyPolicyURL(for: language.code)
                        )
                        Divider().overlay(Palette.gold.opacity(0.2))
                        SettingsChrome.URLRow(
                            title: L10n.t("about.terms"),
                            systemImage: "doc.text",
                            url: AppConfig.termsOfUseURL(for: language.code)
                        )
                        Divider().overlay(Palette.gold.opacity(0.2))
                        SettingsChrome.URLRow(
                            title: L10n.t("about.website"),
                            systemImage: "globe",
                            url: AppConfig.marketingURL(for: language.code)
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SettingsChrome.Panel {
                        SettingsChrome.URLRow(
                            title: L10n.t("about.support"),
                            systemImage: "envelope",
                            url: URL(string: "mailto:\(AppConfig.supportEmail)")!
                        )
                    }
                    SettingsChrome.Footer(text: AppConfig.supportEmail)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SettingsChrome.Panel {
                        SettingsChrome.URLRow(
                            title: L10n.t("hint.bell_link"),
                            systemImage: "bell",
                            url: URL(string: "https://freesound.org/s/66952/")!
                        )
                    }
                    SettingsChrome.Footer(text: L10n.t("hint.bell_credit"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(L10n.t("about.title"))
        .navigationBarTitleDisplayMode(.inline)
        .settingsScreenChrome()
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(Palette.ui(15))
                .foregroundStyle(Palette.ink.opacity(0.72))
            Spacer(minLength: 8)
            Text(value)
                .font(Palette.ui(15).monospacedDigit())
                .foregroundStyle(Palette.ink)
        }
    }
}

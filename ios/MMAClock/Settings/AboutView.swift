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
        List {
            Section {
                LabeledContent(L10n.t("about.app"), value: AppConfig.displayName)
                LabeledContent(L10n.t("about.version"), value: version)
                LabeledContent(L10n.t("about.build"), value: build)
            }

            Section {
                Link(L10n.t("about.privacy"), destination: AppConfig.privacyPolicyURL(for: language.code))
                Link(L10n.t("about.terms"), destination: AppConfig.termsOfUseURL(for: language.code))
                Link(L10n.t("about.website"), destination: AppConfig.marketingURL(for: language.code))
            }

            Section {
                Link(
                    L10n.t("about.support"),
                    destination: URL(string: "mailto:\(AppConfig.supportEmail)")!
                )
            } footer: {
                Text(AppConfig.supportEmail)
            }

            Section {
                Link(L10n.t("hint.bell_link"), destination: URL(string: "https://freesound.org/s/66952/")!)
            } footer: {
                Text(L10n.t("hint.bell_credit"))
            }
        }
        .navigationTitle(L10n.t("about.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

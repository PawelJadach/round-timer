import SwiftUI

struct AboutView: View {
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
                Link(L10n.t("about.privacy"), destination: AppConfig.privacyPolicyURL)
                Link(L10n.t("about.terms"), destination: AppConfig.termsOfUseURL)
                Link(L10n.t("about.website"), destination: AppConfig.marketingURL)
            }

            Section {
                Link(
                    L10n.t("about.support"),
                    destination: URL(string: "mailto:\(AppConfig.supportEmail)")!
                )
            } footer: {
                Text(AppConfig.supportEmail)
            }
        }
        .navigationTitle(L10n.t("about.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

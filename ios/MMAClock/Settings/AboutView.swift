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
                LabeledContent(String(localized: "about.app"), value: AppConfig.displayName)
                LabeledContent(String(localized: "about.version"), value: version)
                LabeledContent(String(localized: "about.build"), value: build)
            }

            Section {
                Link(String(localized: "about.privacy"), destination: AppConfig.privacyPolicyURL)
                Link(String(localized: "about.terms"), destination: AppConfig.termsOfUseURL)
                Link(String(localized: "about.website"), destination: AppConfig.marketingURL)
            }

            Section {
                Link(
                    String(localized: "about.support"),
                    destination: URL(string: "mailto:\(AppConfig.supportEmail)")!
                )
            } footer: {
                Text(AppConfig.supportEmail)
            }
        }
        .navigationTitle(String(localized: "about.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

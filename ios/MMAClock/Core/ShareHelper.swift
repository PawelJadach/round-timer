import SwiftUI
import UIKit

enum ShareHelper {
    struct TextOrURLButton: View {
        let label: String
        let items: [Any]

        init(label: String = String(localized: "share.button"), text: String) {
            self.label = label
            self.items = [text]
        }

        init(label: String = String(localized: "share.button"), url: URL) {
            self.label = label
            self.items = [url]
        }

        var body: some View {
            if let url = items.first as? URL {
                ShareLink(item: url) {
                    Label(label, systemImage: "square.and.arrow.up")
                }
            } else if let text = items.first as? String {
                ShareLink(item: text) {
                    Label(label, systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    @MainActor
    static func present(items: [Any], excluded: [UIActivity.ActivityType] = []) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = excluded
        if let pop = controller.popoverPresentationController {
            pop.sourceView = root.view
            pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        root.present(controller, animated: true)
        Analytics.shared.track("share_presented")
    }
}

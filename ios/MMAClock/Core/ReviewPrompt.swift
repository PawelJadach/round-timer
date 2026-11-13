import StoreKit
import SwiftUI

enum ReviewPrompt {
    @MainActor
    static func recordSuccessfulUseAndMaybeAsk() {
        guard AppConfig.reviewPromptEnabled else { return }

        let defaults = UserDefaults.standard
        let key = AppStorageKeys.successfulUseCount
        let count = defaults.integer(forKey: key) + 1
        defaults.set(count, forKey: key)

        guard count >= AppConfig.reviewPromptAfterSuccessfulUses else { return }

        let askedKey = AppStorageKeys.hasAskedForReview
        guard !defaults.bool(forKey: askedKey) else { return }
        defaults.set(true, forKey: askedKey)

        requestReview()
        Analytics.shared.track("review_prompt_requested", parameters: ["uses": "\(count)"])
    }

    @MainActor
    static func requestReview() {
        guard AppConfig.reviewPromptEnabled else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    #if DEBUG
    static func resetCountersForDebug() {
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.successfulUseCount)
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.hasAskedForReview)
    }
    #endif
}

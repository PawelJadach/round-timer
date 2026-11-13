import SwiftUI

/// Branding and lean App Store feature flags for Train Clock.
enum AppConfig {
    static let displayName = "Train Clock"
    static let bundleIdentifierPlaceholder = "dev.pawel.trainclock"
    static let urlScheme = "trainclock"

    /// Matches web `--work` accent; dark gym clock, not purple AI chrome.
    static let accentColor = Color(red: 1.0, green: 0.306, blue: 0.180)

    static let marketingURL = URL(string: "https://mma-clock.vercel.app")!
    static let supportEmail = "hello@pawel.dev"
    static let privacyPolicyURL = URL(string: "https://mma-clock.vercel.app/privacy")!
    static let termsOfUseURL = URL(string: "https://mma-clock.vercel.app/terms")!

    /// Gym clock should open straight to the timer.
    static let onboardingEnabled = false
    static let storeKitTipsEnabled = false
    static let paywallLiteEnabled = false
    static let reviewPromptEnabled = true
    static let reviewPromptAfterSuccessfulUses = 5
    static let permissionSamplesEnabled = false
    static let screenshotPreviewMode = false
}

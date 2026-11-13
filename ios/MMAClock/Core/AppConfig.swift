import SwiftUI

/// Branding and lean App Store feature flags for Round Timer.
enum AppConfig {
    static let displayName = "Round Timer"
    static let bundleIdentifierPlaceholder = "dev.pawel.roundtimer"
    static let urlScheme = "roundtimer"

    /// Matches web `--work` accent; dark gym clock, not purple AI chrome.
    static let accentColor = Color(red: 1.0, green: 0.306, blue: 0.180)

    static let marketingSiteHost = "https://round-timer-marketing.vercel.app"
    static let supportEmail = "pawel.jadach.96@gmail.com"

    static func marketingURL(for languageCode: String) -> URL {
        if languageCode == "pl" {
            return URL(string: "\(marketingSiteHost)/pl/")!
        }
        return URL(string: "\(marketingSiteHost)/")!
    }

    static func privacyPolicyURL(for languageCode: String) -> URL {
        if languageCode == "pl" {
            return URL(string: "\(marketingSiteHost)/pl/privacy/")!
        }
        return URL(string: "\(marketingSiteHost)/privacy/")!
    }

    static func termsOfUseURL(for languageCode: String) -> URL {
        if languageCode == "pl" {
            return URL(string: "\(marketingSiteHost)/pl/terms/")!
        }
        return URL(string: "\(marketingSiteHost)/terms/")!
    }

    /// Gym clock should open straight to the timer.
    static let onboardingEnabled = false
    static let storeKitTipsEnabled = false
    static let paywallLiteEnabled = false
    static let reviewPromptEnabled = true
    static let reviewPromptAfterSuccessfulUses = 5
    static let permissionSamplesEnabled = false
    static let screenshotPreviewMode = false
}

import Foundation
import SwiftUI

@MainActor
final class AppLanguage: ObservableObject {
    static let shared = AppLanguage()

    @Published private(set) var code: String

    private init() {
        code = Self.resolvedLanguageCode()
    }

    var locale: Locale { Locale(identifier: code) }

    nonisolated func text(_ value: String.LocalizationValue) -> String {
        String(localized: value, locale: Locale(identifier: Self.resolvedLanguageCode()))
    }

    nonisolated private static func resolvedLanguageCode() -> String {
        let stored = UserDefaults.standard.string(forKey: storageKey)
        if stored == "en" || stored == "pl" {
            return stored!
        }
        let system = Locale.current.language.languageCode?.identifier ?? "en"
        return system == "pl" ? "pl" : "en"
    }

    func select(_ next: String) {
        guard next == "en" || next == "pl", next != code else { return }
        code = next
        UserDefaults.standard.set(next, forKey: Self.storageKey)
    }

    private static let storageKey = "mmaclock.language"
}

import Foundation
import SwiftUI

@MainActor
final class AppLanguage: ObservableObject {
    static let shared = AppLanguage()

    @Published private(set) var code: String

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        if stored == "en" || stored == "pl" {
            code = stored!
        } else {
            let system = Locale.current.language.languageCode?.identifier ?? "en"
            code = system == "pl" ? "pl" : "en"
        }
    }

    var locale: Locale { Locale(identifier: code) }

    func text(_ value: String.LocalizationValue) -> String {
        _ = code
        return String(localized: value, locale: locale)
    }

    func select(_ next: String) {
        guard next == "en" || next == "pl", next != code else { return }
        code = next
        UserDefaults.standard.set(next, forKey: Self.storageKey)
    }

    private static let storageKey = "mmaclock.language"
}

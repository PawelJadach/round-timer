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
        let code = Self.resolvedLanguageCode()
        let locale = Locale(identifier: code)
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return String(localized: value, bundle: .main, locale: locale)
        }
        return String(localized: value, bundle: bundle, locale: locale)
    }

    nonisolated private static func resolvedLanguageCode() -> String {
        if let stored = UserDefaults.standard.string(forKey: storageKey),
           stored == "en" || stored == "pl" {
            if !UserDefaults.standard.bool(forKey: overrideKey) {
                UserDefaults.standard.set(true, forKey: overrideKey)
            }
            return stored
        }
        let system = Locale.current.language.languageCode?.identifier ?? "en"
        return system == "pl" ? "pl" : "en"
    }

    func select(_ next: String) {
        guard next == "en" || next == "pl", next != code else { return }
        UserDefaults.standard.set(next, forKey: Self.storageKey)
        UserDefaults.standard.set(true, forKey: Self.overrideKey)
        code = next
    }

    func followSystemLanguage() {
        UserDefaults.standard.removeObject(forKey: Self.overrideKey)
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        let next = Self.resolvedLanguageCode()
        guard next != code else { return }
        code = next
    }

    func syncWithSystemIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.overrideKey) else { return }
        let next = Self.resolvedLanguageCode()
        guard next != code else { return }
        code = next
    }

    var usesManualLanguage: Bool {
        UserDefaults.standard.bool(forKey: Self.overrideKey)
    }

    private static let storageKey = "mmaclock.language"
    private static let overrideKey = "mmaclock.language.override"
}

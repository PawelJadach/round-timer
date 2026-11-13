import Foundation

enum L10n {
    static func t(_ key: String.LocalizationValue) -> String {
        AppLanguage.shared.text(key)
    }
}

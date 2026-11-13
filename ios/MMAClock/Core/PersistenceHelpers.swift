import Foundation

enum Persistence {
    private static var defaults: UserDefaults { .standard }

    static var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: AppStorageKeys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: AppStorageKeys.hasCompletedOnboarding) }
    }

    static func resetOnboardingForDebug() {
        defaults.removeObject(forKey: AppStorageKeys.hasCompletedOnboarding)
    }
}

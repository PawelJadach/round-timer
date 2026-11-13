import SwiftUI

@main
struct MMAClockApp: App {
    @StateObject private var clock = TrainingClock()
    @ObservedObject private var language = AppLanguage.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(clock)
                .environmentObject(language)
                .environment(\.locale, language.locale)
                .preferredColorScheme(.dark)
        }
    }
}

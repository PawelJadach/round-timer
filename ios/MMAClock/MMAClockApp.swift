import SwiftUI

@main
struct MMAClockApp: App {
    @StateObject private var clock = TrainingClock()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(clock)
                .environmentObject(AppLanguage.shared)
                .environment(\.locale, AppLanguage.shared.locale)
                .preferredColorScheme(.dark)
        }
    }
}

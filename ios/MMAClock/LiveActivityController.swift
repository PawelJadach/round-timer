import ActivityKit
import Foundation

/// Live Activity is disabled; only ends any activity left from older app versions.
final class LiveActivityController {
    var areEnabled: Bool { false }

    func beginSession() {}

    func show(title: String, state: TrainingAttributes.ContentState, force: Bool = false) {}

    func stop() {
        let existing = Activity<TrainingAttributes>.activities
        Task { @MainActor in
            for activity in existing {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
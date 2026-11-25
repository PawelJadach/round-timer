import ActivityKit
import Foundation

final class LiveActivityController {
    private var activity: Activity<TrainingAttributes>?
    private var title: String?
    private var last: TrainingAttributes.ContentState?
    private var token = 0
    private var monitor: Task<Void, Never>?
    private var userDismissed = false

    var areEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func beginSession() {
        userDismissed = false
    }

    func show(title: String, state: TrainingAttributes.ContentState) {
        guard areEnabled, !userDismissed else { return }
        scrubInactiveReference()

        if let current = activity, isPresenting(current), self.title == title {
            guard last != state else { return }
            last = state
            let stale = state.usesTimer ? state.rangeEnd : nil
            Task { @MainActor in
                await current.update(ActivityContent(state: state, staleDate: stale))
            }
            return
        }

        guard !userDismissed else { return }
        token += 1
        let myToken = token
        self.title = title
        last = state
        Task { @MainActor in
            guard myToken == self.token else { return }
            for existing in Activity<TrainingAttributes>.activities {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
            guard myToken == self.token else { return }
            do {
                let created = try Activity.request(
                    attributes: TrainingAttributes(title: title),
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
                guard myToken == self.token else {
                    await created.end(nil, dismissalPolicy: .immediate)
                    return
                }
                self.activity = created
                observeDismissal(created)
            } catch {
                print("MMA Clock: Live Activity: \(error.localizedDescription)")
                self.activity = nil
            }
        }
    }

    func stop() {
        token += 1
        userDismissed = false
        monitor?.cancel()
        monitor = nil
        let existing = Activity<TrainingAttributes>.activities
        activity = nil
        title = nil
        last = nil
        Task { @MainActor in
            for activity in existing {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func observeDismissal(_ activity: Activity<TrainingAttributes>) {
        monitor?.cancel()
        monitor = Task { @MainActor in
            if activity.activityState == .dismissed {
                markUserDismissed()
                return
            }
            for await state in activity.activityStateUpdates {
                guard !Task.isCancelled else { return }
                guard state == .dismissed else { continue }
                markUserDismissed()
                return
            }
        }
    }

    private func markUserDismissed() {
        userDismissed = true
        monitor?.cancel()
        monitor = nil
        activity = nil
        title = nil
        last = nil
    }

    private func scrubInactiveReference() {
        guard let current = activity, !isPresenting(current) else { return }
        activity = nil
        last = nil
    }

    private func isPresenting(_ activity: Activity<TrainingAttributes>) -> Bool {
        switch activity.activityState {
        case .active, .stale:
            return true
        default:
            return false
        }
    }
}
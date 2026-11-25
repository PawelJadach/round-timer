import ActivityKit
import Foundation

final class LiveActivityController {
    private var activity: Activity<TrainingAttributes>?
    private var title: String?
    private var last: TrainingAttributes.ContentState?
    private var token = 0
    private var monitor: Task<Void, Never>?
    var onDismissed: (() -> Void)?

    var areEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func show(title: String, state: TrainingAttributes.ContentState) {
        guard areEnabled else { return }
        if let current = activity, current.activityState == .dismissed {
            activity = nil
            last = nil
        }
        if activity != nil, self.title == title {
            guard last != state else { return }
            last = state
            let current = activity
            let stale = state.usesTimer ? state.rangeEnd : nil
            Task { @MainActor in
                await current?.update(ActivityContent(state: state, staleDate: stale))
            }
            return
        }

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
                self.observeDismissal(created)
            } catch {
                print("MMA Clock: Live Activity: \(error.localizedDescription)")
                self.activity = nil
            }
        }
    }

    func stop() {
        token += 1
        let myToken = token
        monitor?.cancel()
        monitor = nil
        let existing = Activity<TrainingAttributes>.activities
        activity = nil
        title = nil
        last = nil
        Task { @MainActor in
            guard myToken == self.token else { return }
            for activity in existing {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func observeDismissal(_ activity: Activity<TrainingAttributes>) {
        monitor?.cancel()
        monitor = Task { @MainActor in
            for await state in activity.activityStateUpdates {
                guard !Task.isCancelled else { return }
                guard state == .dismissed else { continue }
                if self.activity?.id == activity.id {
                    self.activity = nil
                    self.last = nil
                }
                self.onDismissed?()
                return
            }
        }
    }
}
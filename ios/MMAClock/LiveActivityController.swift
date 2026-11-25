import ActivityKit
import Foundation

final class LiveActivityController {
    private var activity: Activity<TrainingAttributes>?
    private var title: String?
    private var last: TrainingAttributes.ContentState?
    private var token = 0
    private var monitor: Task<Void, Never>?
    private var pendingCreate = false
    var onDismissed: (() -> Void)?

    var areEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isVisibleOnSystem: Bool {
        Activity<TrainingAttributes>.activities.contains { isPresenting($0) }
    }

    var shouldReassertAfterDismissal: Bool {
        !pendingCreate && !isVisibleOnSystem
    }

    func show(title: String, state: TrainingAttributes.ContentState) {
        guard areEnabled else { return }
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

        requestActivity(title: title, state: state)
    }

    /// Called when the user swipes the Live Activity away during an active session.
    func restoreAfterUserDismissal(title: String, state: TrainingAttributes.ContentState) {
        guard areEnabled else { return }
        monitor?.cancel()
        monitor = nil
        activity = nil
        self.title = nil
        last = nil
        requestActivity(title: title, state: state)
    }

    func stop() {
        token += 1
        pendingCreate = false
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

    private func requestActivity(title: String, state: TrainingAttributes.ContentState) {
        token += 1
        let myToken = token
        self.title = title
        last = state
        pendingCreate = true
        Task { @MainActor in
            defer {
                if myToken == self.token {
                    self.pendingCreate = false
                }
            }
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

    private func observeDismissal(_ activity: Activity<TrainingAttributes>) {
        monitor?.cancel()
        monitor = Task { @MainActor in
            if activity.activityState == .dismissed {
                handleDismissal(of: activity)
                return
            }
            for await state in activity.activityStateUpdates {
                guard !Task.isCancelled else { return }
                guard state == .dismissed else { continue }
                handleDismissal(of: activity)
                return
            }
        }
    }

    private func handleDismissal(of activity: Activity<TrainingAttributes>) {
        guard self.activity?.id == activity.id else { return }
        self.activity = nil
        self.title = nil
        last = nil
        onDismissed?()
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
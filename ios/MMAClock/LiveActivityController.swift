import ActivityKit
import Foundation

final class LiveActivityController {
    private var activity: Activity<TrainingAttributes>?
    private var title: String?
    private var last: TrainingAttributes.ContentState?
    private var token = 0

    var areEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func show(title: String, state: TrainingAttributes.ContentState) {
        guard areEnabled else { return }
        if activity != nil, self.title == title {
            guard last != state else { return }
            last = state
            let current = activity
            Task { await current?.update(ActivityContent(state: state, staleDate: nil)) }
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
            } catch {
                print("MMA Clock: Live Activity: \(error.localizedDescription)")
                self.activity = nil
            }
        }
    }

    func stop() {
        token += 1
        let myToken = token
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
}

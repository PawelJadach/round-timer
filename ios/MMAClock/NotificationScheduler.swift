import Foundation
import UserNotifications

/// Backup cues for when iOS suspends the app. They fire about a second after the
/// real boundary. While the app is still awake it plays the sound itself and cancels
/// the pending notification, so the beep is not doubled.
final class NotificationScheduler {
    private let center = UNUserNotificationCenter.current()

    func schedule(_ cues: [Cue]) {
        center.removeAllPendingNotificationRequests()
        for cue in cues where cue.sound != .tick {
            let untilCue = cue.date.timeIntervalSinceNow
            // Time-interval triggers must be at least 1 second. The extra 0.35 s
            // lets a living app cancel this alert and play the beep itself.
            guard untilCue >= 1 else { continue }
            let content = UNMutableNotificationContent()
            content.title = cue.title
            content.body = cue.body
            content.sound = UNNotificationSound(named: UNNotificationSoundName(cue.sound.filename))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: untilCue + 0.35, repeats: false)
            let request = UNNotificationRequest(identifier: "mmaclock.\(cue.id)", content: content, trigger: trigger)
            center.add(request) { error in
                if let error {
                    print("MMA Clock: powiadomienie \(cue.id): \(error.localizedDescription)")
                }
            }
        }
    }

    func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["mmaclock.\(id)"])
    }

    func cancelPending() {
        center.removeAllPendingNotificationRequests()
    }

    func clearDelivered() {
        center.removeAllDeliveredNotifications()
    }
}

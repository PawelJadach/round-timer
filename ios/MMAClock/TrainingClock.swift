import Combine
import Foundation
import UIKit
import UserNotifications

enum TrainingMode: String, CaseIterable, Identifiable {
    case sparring
    case countdown
    case stopwatch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sparring: return AppLanguage.shared.text("mode.sparring")
        case .countdown: return AppLanguage.shared.text("mode.countdown")
        case .stopwatch: return AppLanguage.shared.text("mode.stopwatch")
        }
    }
}

enum RunState: Equatable {
    case idle
    case running
    case paused
    case finished
}

enum AlertPermission: Equatable {
    case unknown
    case needsPrompt
    case denied
    case allowed
}

struct Face: Equatable {
    var text: String
    var phaseName: String
    var detail: String
    var tint: String
}

final class TrainingClock: ObservableObject {
    @Published private(set) var mode: TrainingMode = .sparring
    @Published private(set) var runState: RunState = .idle
    @Published private(set) var face = Face(text: "03:00", phaseName: "PRACA", detail: "Runda 1 z 5", tint: "work")
    @Published private(set) var laps: [Lap] = []
    @Published var notificationStatus: AlertPermission = .unknown
    @Published var liveActivitiesOff = false

    @Published var prepareSeconds: Int = 10 { didSet { persist() } }
    @Published var workSeconds: Int = 180 { didSet { persist() } }
    @Published var restSeconds: Int = 60 { didSet { persist() } }
    @Published var rounds: Int = 5 { didSet { persist() } }
    @Published var countdownSeconds: Int = 180 { didSet { persist() } }
    @Published var soundEnabled: Bool = true {
        didSet {
            guard soundEnabled != oldValue else { return }
            persist()
            applySoundChange()
        }
    }

    /// 0...100. Default 80 matches the web slider.
    @Published var cueVolume: Double = 80 {
        didSet {
            let clamped = min(100, max(0, cueVolume))
            if clamped != cueVolume {
                cueVolume = clamped
                return
            }
            guard cueVolume != oldValue else { return }
            persist()
            player.cueGain = Float(cueVolume / 100)
        }
    }

    private let player = CuePlayer()
    private let scheduler = NotificationScheduler()
    private let activities = LiveActivityController()
    private var timeline: SessionTimeline?
    private var stopwatch = StopwatchState()
    private var lastPoll: Date?
    private var ticker: Timer?
    private var activityKey: String?

    private enum Key {
        static let prepare = "mmaclock.prepare"
        static let work = "mmaclock.work"
        static let rest = "mmaclock.rest"
        static let rounds = "mmaclock.rounds"
        static let countdown = "mmaclock.countdown"
        static let sound = "mmaclock.sound"
        static let volume = "mmaclock.volume"
    }

    init() {
        player.onInterruptionBegan = { [weak self] in
            self?.pause()
        }
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Key.volume) != nil {
            cueVolume = Double(Self.clamp(defaults.integer(forKey: Key.volume), 0...100))
        }
        player.cueGain = Float(cueVolume / 100)
        guard defaults.object(forKey: Key.work) != nil else { return }
        prepareSeconds = Self.clamp(defaults.integer(forKey: Key.prepare), 0...120)
        workSeconds = Self.clamp(defaults.integer(forKey: Key.work), 5...3600)
        restSeconds = Self.clamp(defaults.integer(forKey: Key.rest), 0...1800)
        rounds = Self.clamp(defaults.integer(forKey: Key.rounds), 1...30)
        countdownSeconds = Self.clamp(defaults.integer(forKey: Key.countdown), 0...86_400)
        if defaults.object(forKey: Key.sound) != nil {
            soundEnabled = defaults.bool(forKey: Key.sound)
        }
    }

    var sparringTotalSeconds: Int {
        prepareSeconds + rounds * workSeconds + max(0, rounds - 1) * restSeconds
    }

    /// Plays the ring bell once when the idle volume slider is released.
    func previewVolume() {
        guard runState == .idle, soundEnabled, cueVolume > 0 else { return }
        player.playBell()
    }

    func relocalize() {
        timeline?.refreshLocalizedCopy()
        let now = Date()
        switch runState {
        case .idle:
            break
        case .running, .paused:
            if mode == .stopwatch {
                publishStopwatch(at: now)
            } else if let snap = timeline?.snapshot(at: now) {
                if runState == .paused {
                    publish(Face(
                        text: ClockFormat.remaining(snap.remaining),
                        phaseName: AppLanguage.shared.text("phase.pause"),
                        detail: snap.detail,
                        tint: snap.tint
                    ))
                } else {
                    publish(face(from: snap))
                }
            }
            showActivity(at: now, force: true)
            if runState == .running, mode != .stopwatch, soundEnabled {
                enqueueBoundaryNotifications()
            }
        case .finished:
            let detail = mode == .countdown
                ? AppLanguage.shared.text("detail.finished_countdown")
                : AppLanguage.shared.text("detail.finished_session")
            publish(Face(text: "00:00", phaseName: AppLanguage.shared.text("phase.end"), detail: detail, tint: "end"))
            showActivity(at: now, force: true)
        }
    }

    func canStart(_ mode: TrainingMode) -> Bool {
        switch mode {
        case .sparring: return workSeconds >= 5 && rounds >= 1
        case .countdown: return countdownSeconds >= 5
        case .stopwatch: return true
        }
    }

    func previewFace(for mode: TrainingMode) -> Face {
        switch mode {
        case .sparring:
            let opening = prepareSeconds > 0 ? prepareSeconds : workSeconds
            return Face(
                text: ClockFormat.clock(seconds: opening),
                phaseName: prepareSeconds > 0 ? AppLanguage.shared.text("phase.prepare") : AppLanguage.shared.text("phase.work"),
                detail: AppLanguage.shared.text("detail.round \(1) of \(rounds)"),
                tint: prepareSeconds > 0 ? "prepare" : "work"
            )
        case .countdown:
            return Face(
                text: ClockFormat.clock(seconds: max(countdownSeconds, 0)),
                phaseName: AppLanguage.shared.text("phase.countdown"),
                detail: countdownSeconds < 5
                    ? AppLanguage.shared.text("detail.countdown_minimum")
                    : AppLanguage.shared.text("detail.countdown"),
                tint: "work"
            )
        case .stopwatch:
            return Face(
                text: "00:00.00",
                phaseName: AppLanguage.shared.text("phase.stopwatch"),
                detail: AppLanguage.shared.text("detail.stopwatch_ready"),
                tint: "stopwatch"
            )
        }
    }

    func start(mode: TrainingMode) {
        guard canStart(mode) else { return }
        tearDownAudio()
        self.mode = mode
        activityKey = nil
        let now = Date()

        switch mode {
        case .stopwatch:
            stopwatch.reset()
            laps = []
            stopwatch.start(at: now)
            runState = .running
            publishStopwatch(at: now)
            showActivity(at: now, force: true)
            startTicker()
        case .sparring:
            timeline = SessionTimeline.tabata(
                prepare: prepareSeconds,
                work: workSeconds,
                rest: restSeconds,
                rounds: rounds,
                start: now
            )
            beginIntervals(at: now)
        case .countdown:
            timeline = SessionTimeline.countdown(seconds: countdownSeconds, start: now)
            beginIntervals(at: now)
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func pause() {
        guard runState == .running else { return }
        let now = Date()
        if mode != .stopwatch {
            poll(now: now)
            guard runState == .running else { return }
        }
        stopTicker()
        if mode == .stopwatch {
            stopwatch.pause(at: now)
            runState = .paused
            publishStopwatch(at: now)
        } else {
            timeline?.pause(at: now)
            scheduler.cancelPending()
            player.deactivate()
            runState = .paused
            if let snap = timeline?.snapshot(at: now) {
                publish(Face(
                    text: ClockFormat.remaining(snap.remaining),
                    phaseName: AppLanguage.shared.text("phase.pause"),
                    detail: snap.detail,
                    tint: snap.tint
                ))
            }
        }
        showActivity(at: now, force: true)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func resume() {
        guard runState == .paused else { return }
        let now = Date()
        runState = .running
        if mode == .stopwatch {
            stopwatch.start(at: now)
            publishStopwatch(at: now)
        } else {
            timeline?.resume(at: now)
            lastPoll = now
            player.activate()
            armNotifications()
            if let snap = timeline?.snapshot(at: now) {
                publish(Face(
                    text: ClockFormat.remaining(snap.remaining),
                    phaseName: snap.phaseName,
                    detail: snap.detail,
                    tint: snap.tint
                ))
            }
        }
        startTicker()
        showActivity(at: now, force: true)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func reset() {
        tearDownAudio()
        scheduler.cancelPending()
        activities.stop()
        timeline = nil
        stopwatch.reset()
        laps = []
        lastPoll = nil
        activityKey = nil
        runState = .idle
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func lap() {
        guard mode == .stopwatch, runState == .running else { return }
        _ = stopwatch.lap(at: Date())
        laps = stopwatch.laps
        guard soundEnabled else { return }
        if player.playCue(.tick) {
            haptic(.tick)
        }
    }

    func catchUp() {
        guard runState == .running else { return }
        player.cancelScheduled(after: Date().addingTimeInterval(0.05))
        let now = Date()
        if mode == .stopwatch {
            publishStopwatch(at: now)
            startTicker()
            return
        }
        let gap = lastPoll.map { now.timeIntervalSince($0) } ?? 0
        if gap > 2 {
            lastPoll = now
            guard let timeline else { return }
            let snap = timeline.snapshot(at: now)
            if snap.isFinished {
                enterFinished(at: now)
            } else {
                publish(face(from: snap))
                showActivity(at: now, force: true)
                startTicker()
            }
        } else {
            poll(now: now)
            startTicker()
        }
    }

    func refreshCapabilities() {
        liveActivitiesOff = !activities.areEnabled
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationStatus = Self.map(settings.authorizationStatus)
            }
        }
    }

    func requestNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self else { return }
                switch settings.authorizationStatus {
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        DispatchQueue.main.async {
                            self.notificationStatus = granted ? .allowed : .denied
                            if granted { self.enqueueBoundaryNotifications() }
                        }
                    }
                case .denied:
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                default:
                    self.notificationStatus = .allowed
                }
            }
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// Keeps the playback session alive and arms cue sounds on the audio clock.
    /// Notifications stay the backup only when that session could not be armed.
    func prepareForBackground() {
        guard runState == .running, mode != .stopwatch else { return }
        player.ensureRunning()
        guard soundEnabled, let timeline else { return }
        let cues = timeline.cues.map { (id: $0.id, date: $0.date, sound: $0.sound) }
        let armed = player.scheduleCues(cues)
        if armed.isEmpty {
            enqueueBoundaryNotifications()
        } else {
            scheduler.cancelPending()
        }
    }

    private func beginIntervals(at now: Date) {
        lastPoll = now.addingTimeInterval(-0.01)
        runState = .running
        player.activate()
        scheduler.clearDelivered()
        armNotifications()
        poll(now: now)
        startTicker()
    }

    private func poll(now: Date = Date()) {
        guard runState == .running else { return }
        if mode == .stopwatch {
            publishStopwatch(at: now)
            return
        }
        guard let timeline else { return }
        player.ensureRunning()
        let due = timeline.dueCues(after: lastPoll ?? now.addingTimeInterval(-0.01), through: now)
        lastPoll = now
        let snap = timeline.snapshot(at: now)
        for cue in due where cue.sound != .end {
            playIfFresh(cue, now: now)
        }
        if snap.isFinished {
            if let end = due.first(where: { $0.sound == .end }) {
                playIfFresh(end, now: now)
            }
            enterFinished(at: now)
            return
        }
        publish(face(from: snap))
        showActivity(at: now)
    }

    private func playIfFresh(_ cue: Cue, now: Date) {
        if player.isScheduled(cue.id) {
            scheduler.cancel(id: cue.id)
            return
        }
        let late = now.timeIntervalSince(cue.date)
        guard late < 1.5 else {
            scheduler.cancel(id: cue.id)
            return
        }
        guard soundEnabled else {
            scheduler.cancel(id: cue.id)
            return
        }
        if player.playCue(cue.sound) {
            scheduler.cancel(id: cue.id)
            haptic(cue.sound)
        }
    }

    private func enterFinished(at now: Date) {
        guard runState == .running else { return }
        runState = .finished
        stopTicker()
        let detail = mode == .countdown
            ? AppLanguage.shared.text("detail.finished_countdown")
            : AppLanguage.shared.text("detail.finished_session")
        publish(Face(text: "00:00", phaseName: AppLanguage.shared.text("phase.end"), detail: detail, tint: "end"))
        showActivity(at: now, force: true)
        UIApplication.shared.isIdleTimerDisabled = false
        Task { @MainActor in
            ReviewPrompt.recordSuccessfulUseAndMaybeAsk()
        }
        Analytics.shared.track("session_finished", parameters: ["mode": mode.rawValue])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self, self.runState == .finished else { return }
            self.player.deactivate()
        }
    }

    private func publishStopwatch(at now: Date) {
        publish(Face(
            text: ClockFormat.stopwatch(stopwatch.elapsed(at: now)),
            phaseName: runState == .paused
                ? AppLanguage.shared.text("phase.pause")
                : AppLanguage.shared.text("phase.stopwatch"),
            detail: laps.isEmpty
                ? AppLanguage.shared.text("detail.stopwatch_idle")
                : AppLanguage.shared.text("detail.lap_count \(laps.count)"),
            tint: "stopwatch"
        ))
    }

    private func face(from snap: ClockSnapshot) -> Face {
        Face(
            text: ClockFormat.remaining(snap.remaining),
            phaseName: snap.phaseName,
            detail: snap.detail,
            tint: snap.tint
        )
    }

    private func publish(_ next: Face) {
        if face != next { face = next }
    }

    private func showActivity(at now: Date, force: Bool = false) {
        let state = activityState(at: now)
        let key = [
            state.phaseName,
            state.detail,
            state.usesTimer ? "run" : "hold",
            state.countsDown ? "down" : "up",
            String(Int(state.rangeEnd.timeIntervalSince1970)),
            state.usesTimer ? "" : state.frozenText
        ].joined(separator: "|")
        if !force, key == activityKey { return }
        activityKey = key
        activities.show(title: mode.title, state: state)
    }

    private func activityState(at now: Date) -> TrainingAttributes.ContentState {
        if mode == .stopwatch {
            let elapsed = stopwatch.elapsed(at: now)
            let start = now.addingTimeInterval(-elapsed)
            let running = runState == .running
            return TrainingAttributes.ContentState(
                phaseName: running ? AppLanguage.shared.text("phase.stopwatch") : AppLanguage.shared.text("phase.pause"),
                detail: AppLanguage.shared.text("detail.stopwatch_idle"),
                tint: "stopwatch",
                usesTimer: running,
                countsDown: false,
                rangeStart: start,
                rangeEnd: start.addingTimeInterval(86_400),
                frozenText: ClockFormat.stopwatch(elapsed)
            )
        }

        if runState == .finished {
            return TrainingAttributes.ContentState(
                phaseName: AppLanguage.shared.text("phase.end"),
                detail: mode == .countdown
                    ? AppLanguage.shared.text("detail.finished_countdown")
                    : AppLanguage.shared.text("detail.finished_session"),
                tint: "end",
                usesTimer: false,
                countsDown: true,
                rangeStart: now,
                rangeEnd: now.addingTimeInterval(1),
                frozenText: "00:00"
            )
        }

        let snap = timeline?.snapshot(at: now) ?? .empty
        let running = runState == .running && !snap.isFinished
        let end = max(snap.segmentEnd, snap.segmentStart.addingTimeInterval(0.5))
        return TrainingAttributes.ContentState(
            phaseName: running ? snap.phaseName : AppLanguage.shared.text("phase.pause"),
            detail: snap.detail,
            tint: snap.tint,
            usesTimer: running,
            countsDown: true,
            rangeStart: snap.segmentStart,
            rangeEnd: end,
            frozenText: ClockFormat.remaining(snap.remaining)
        )
    }

    private func applySoundChange() {
        guard runState == .running, mode != .stopwatch else {
            if !soundEnabled { scheduler.cancelPending() }
            return
        }
        if soundEnabled {
            armNotifications()
        } else {
            scheduler.cancelPending()
        }
    }

    private func armNotifications() {
        guard soundEnabled, mode != .stopwatch, runState == .running else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            if status == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.notificationStatus = granted ? .allowed : .denied
                        if granted { self.enqueueBoundaryNotifications() }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.notificationStatus = Self.map(status)
                    if self.notificationStatus == .allowed {
                        self.enqueueBoundaryNotifications()
                    }
                }
            }
        }
    }

    private func enqueueBoundaryNotifications() {
        guard soundEnabled, runState == .running, let timeline else { return }
        scheduler.cancelPending()
        scheduler.schedule(timeline.futureBoundaryCues(after: Date()))
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tearDownAudio() {
        stopTicker()
        player.deactivate()
        scheduler.cancelPending()
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(prepareSeconds, forKey: Key.prepare)
        defaults.set(workSeconds, forKey: Key.work)
        defaults.set(restSeconds, forKey: Key.rest)
        defaults.set(rounds, forKey: Key.rounds)
        defaults.set(countdownSeconds, forKey: Key.countdown)
        defaults.set(soundEnabled, forKey: Key.sound)
        defaults.set(Int(cueVolume.rounded()), forKey: Key.volume)
    }

    private func haptic(_ sound: SoundID) {
        switch sound {
        case .work:
            HapticFeedback.success()
        case .rest:
            HapticFeedback.warning()
        case .end:
            HapticFeedback.error()
        case .prepare, .tick:
            HapticFeedback.rigid()
        }
    }

    private static func map(_ status: UNAuthorizationStatus) -> AlertPermission {
        switch status {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .denied: return .denied
        case .notDetermined: return .needsPrompt
        @unknown default: return .needsPrompt
        }
    }

    private static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }
}

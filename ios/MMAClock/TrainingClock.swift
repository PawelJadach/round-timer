import Combine
import Foundation
import QuartzCore
import UIKit
import UserNotifications

private final class DisplayLinkDriver: NSObject {
    private var link: CADisplayLink?
    var onTick: ((Date) -> Void)?

    func start() {
        stop()
        let link = CADisplayLink(target: self, selector: #selector(step))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 60, preferred: 30)
        }
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step() {
        onTick?(Date())
    }

    deinit { stop() }
}

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

struct ClockReadout: Equatable {
    var usesTimer: Bool
    var countsDown: Bool
    var rangeStart: Date
    var rangeEnd: Date
    var frozenText: String

    static func frozen(_ text: String) -> ClockReadout {
        ClockReadout(
            usesTimer: false,
            countsDown: true,
            rangeStart: .distantPast,
            rangeEnd: .distantPast,
            frozenText: text
        )
    }

    var segmentIdentity: String {
        guard usesTimer else { return "frozen|\(frozenText)" }
        return "\(rangeStart.timeIntervalSince1970)|\(rangeEnd.timeIntervalSince1970)"
    }
}

final class TrainingClock: ObservableObject {
    @Published private(set) var mode: TrainingMode = .sparring
    @Published private(set) var runState: RunState = .idle
    @Published private(set) var face = Face(text: "03:00", phaseName: "PRACA", detail: "Runda 1 z 5", tint: "work")
    @Published private(set) var readout = ClockReadout.frozen("03:00")
    /// Bumps every display refresh so labels track wall time while digits use `Text(timerInterval:)`.
    @Published private(set) var uiNow = Date()
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
    private let displayLink = DisplayLinkDriver()

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
            guard let self else { return }
            // Phone calls and Siri briefly cut the audio session. Do not pause
            // interval training here — that leaves the face on rest/work 0:00.
            if self.runState == .running {
                self.player.ensureRunning()
            }
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
            showActivity(at: now)
            if runState == .running, mode != .stopwatch, soundEnabled {
                enqueueBoundaryNotifications()
            }
        case .finished:
            let detail = mode == .countdown
                ? AppLanguage.shared.text("detail.finished_countdown")
                : AppLanguage.shared.text("detail.finished_session")
            publish(Face(text: "00:00", phaseName: AppLanguage.shared.text("phase.end"), detail: detail, tint: "end"))
            showActivity(at: now)
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
        activities.beginSession()
        let now = Date()

        switch mode {
        case .stopwatch:
            stopwatch.reset()
            laps = []
            stopwatch.start(at: now)
            runState = .running
            publishStopwatch(at: now)
            showActivity(at: now)
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
        showActivity(at: now)
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
        showActivity(at: now)
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

    func sessionSegmentIdentity(at date: Date) -> String {
        guard runState == .running, mode != .stopwatch, let timeline else { return "idle" }
        let snap = timeline.snapshot(at: date)
        return "\(snap.tint)|\(snap.segmentStart.timeIntervalSince1970)|\(snap.segmentEnd.timeIntervalSince1970)"
    }

    /// Face derived from wall-clock time for on-screen rendering (independent of poll/ticker).
    func sessionFace(at date: Date) -> Face {
        switch runState {
        case .idle:
            return previewFace(for: mode)
        case .paused:
            guard let timeline else { return face }
            return face(from: timeline.snapshot(at: date))
        case .finished:
            return face
        case .running:
            if mode == .stopwatch {
                return Face(
                    text: ClockFormat.stopwatch(stopwatch.elapsed(at: date)),
                    phaseName: AppLanguage.shared.text("phase.stopwatch"),
                    detail: laps.isEmpty
                        ? AppLanguage.shared.text("detail.stopwatch_idle")
                        : AppLanguage.shared.text("detail.lap_count \(laps.count)"),
                    tint: "stopwatch"
                )
            }
            guard let timeline else { return face }
            let snap = timeline.snapshot(at: date)
            if snap.isFinished {
                let detail = mode == .countdown
                    ? AppLanguage.shared.text("detail.finished_countdown")
                    : AppLanguage.shared.text("detail.finished_session")
                return Face(
                    text: "00:00",
                    phaseName: AppLanguage.shared.text("phase.end"),
                    detail: detail,
                    tint: "end"
                )
            }
            return face(from: snap)
        }
    }

    func catchUp() {
        guard runState == .running else { return }
        player.cancelScheduled(after: Date().addingTimeInterval(0.05))
        let now = Date()
        uiNow = now
        if mode == .stopwatch {
            publishStopwatch(at: now)
            showActivity(at: now)
            startTicker()
            return
        }
        poll(now: now)
        guard runState == .running else { return }
        if mode != .stopwatch {
            publishPresentation(at: Date())
        }
        startTicker()
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
        syncPresentation(at: Date())
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
        let snap = timeline.snapshot(at: now)
        let cueThrough = (!snap.isFinished && snap.remaining < 0.25)
            ? max(now, snap.segmentEnd)
            : now
        let due = timeline.dueCues(after: lastPoll ?? now.addingTimeInterval(-0.01), through: cueThrough)
        lastPoll = now
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
        publishPresentation(at: now)
    }

    private func isPhaseBoundaryCue(_ cue: Cue) -> Bool {
        switch cue.sound {
        case .work, .rest, .prepare: return true
        case .tick, .end: return false
        }
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
        showActivity(at: now)
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

    /// Single wall-clock presentation for in-app face, readout, and Live Activity.
    private func publishPresentation(at now: Date) {
        guard let timeline else { return }
        let snap = timeline.snapshot(at: now)
        publish(face(from: snap), at: now)
        showActivity(at: now)
    }

    private func publish(_ next: Face, at now: Date = Date()) {
        face = next
        refreshReadout(at: now)
    }

    private func refreshReadout(at now: Date) {
        let state = activityState(at: now)
        let next = ClockReadout(
            usesTimer: state.usesTimer,
            countsDown: state.countsDown,
            rangeStart: state.rangeStart,
            rangeEnd: state.rangeEnd,
            frozenText: state.frozenText
        )
        readout = next
    }

    private func showActivity(at now: Date) {
        activities.show(title: mode.title, state: activityState(at: now), force: true)
    }

    /// Refreshes on-screen state and Live Activity from wall clock (e.g. before suspend).
    func syncPresentation(at now: Date = Date()) {
        uiNow = now
        guard runState == .running || runState == .paused else { return }
        switch runState {
        case .running:
            poll(now: now)
        case .paused:
            publishPresentation(at: now)
        default:
            break
        }
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

    private var pollTimer: Timer?
    private var uiSecondTimer: Timer?

    private func startTicker() {
        stopTicker()
        uiNow = Date()
        let poll = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.poll(now: Date())
        }
        RunLoop.main.add(poll, forMode: .common)
        pollTimer = poll

        let secondPulse = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.uiNow = Date()
        }
        RunLoop.main.add(secondPulse, forMode: .common)
        uiSecondTimer = secondPulse

        displayLink.onTick = { [weak self] now in
            self?.uiNow = now
        }
        displayLink.start()
    }

    private func stopTicker() {
        pollTimer?.invalidate()
        pollTimer = nil
        uiSecondTimer?.invalidate()
        uiSecondTimer = nil
        displayLink.stop()
        displayLink.onTick = nil
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

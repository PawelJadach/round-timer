import Foundation

enum PhaseKind: String, Equatable {
    case prepare
    case work
    case rest
    case countdown
    case finished
}

enum SoundID: String, Equatable {
    case prepare
    case work
    case rest
    case tick
    case end

    var resource: String { "cue_\(rawValue)" }
    var filename: String { "cue_\(rawValue).wav" }
}

struct Cue: Equatable {
    var id: String
    var date: Date
    var sound: SoundID
    var title: String
    var body: String
}

struct Segment: Equatable {
    var kind: PhaseKind
    var start: Date
    var end: Date
    var round: Int
    var totalRounds: Int
}

struct ClockSnapshot: Equatable {
    var phase: PhaseKind
    var remaining: TimeInterval
    var round: Int
    var totalRounds: Int
    var segmentStart: Date
    var segmentEnd: Date
    var isFinished: Bool

    var phaseName: String {
        switch phase {
        case .prepare: return AppLanguage.shared.text("phase.prepare")
        case .work: return AppLanguage.shared.text("phase.work")
        case .rest: return AppLanguage.shared.text("phase.rest")
        case .countdown: return AppLanguage.shared.text("phase.countdown")
        case .finished: return AppLanguage.shared.text("phase.end")
        }
    }

    var detail: String {
        switch phase {
        case .prepare:
            return AppLanguage.shared.text("detail.prepare")
        case .work, .rest:
            return AppLanguage.shared.text("detail.round \(max(round, 1)) of \(max(totalRounds, 1))")
        case .countdown:
            return AppLanguage.shared.text("detail.countdown")
        case .finished:
            return AppLanguage.shared.text("detail.finished_session")
        }
    }

    var tint: String {
        switch phase {
        case .prepare: return "prepare"
        case .work, .countdown: return "work"
        case .rest: return "rest"
        case .finished: return "end"
        }
    }

    static let empty = ClockSnapshot(
        phase: .finished,
        remaining: 0,
        round: 0,
        totalRounds: 0,
        segmentStart: .distantPast,
        segmentEnd: .distantPast,
        isFinished: true
    )
}

struct SessionTimeline {
    private(set) var segments: [Segment]
    private(set) var cues: [Cue]
    private(set) var pauseBegan: Date?

    static func tabata(prepare: Int, work: Int, rest: Int, rounds: Int, start: Date) -> SessionTimeline {
        let safeRounds = max(1, rounds)
        let safeWork = max(1, work)
        let safeRest = max(0, rest)
        let safePrepare = max(0, prepare)
        var segments: [Segment] = []
        var cursor = start

        if safePrepare > 0 {
            let end = cursor.addingTimeInterval(TimeInterval(safePrepare))
            segments.append(Segment(kind: .prepare, start: cursor, end: end, round: 1, totalRounds: safeRounds))
            cursor = end
        }

        for round in 1...safeRounds {
            let workEnd = cursor.addingTimeInterval(TimeInterval(safeWork))
            segments.append(Segment(kind: .work, start: cursor, end: workEnd, round: round, totalRounds: safeRounds))
            cursor = workEnd
            if safeRest > 0, round < safeRounds {
                let restEnd = cursor.addingTimeInterval(TimeInterval(safeRest))
                segments.append(Segment(kind: .rest, start: cursor, end: restEnd, round: round, totalRounds: safeRounds))
                cursor = restEnd
            }
        }

        return SessionTimeline(segments: segments, cues: makeCues(segments: segments), pauseBegan: nil)
    }

    static func countdown(seconds: Int, start: Date) -> SessionTimeline {
        let duration = max(1, seconds)
        let end = start.addingTimeInterval(TimeInterval(duration))
        let segments = [Segment(kind: .countdown, start: start, end: end, round: 1, totalRounds: 1)]
        return SessionTimeline(segments: segments, cues: makeCues(segments: segments), pauseBegan: nil)
    }

    func snapshot(at now: Date) -> ClockSnapshot {
        let time = pauseBegan ?? now
        guard let last = segments.last else { return .empty }
        if time >= last.end {
            return ClockSnapshot(
                phase: .finished,
                remaining: 0,
                round: last.round,
                totalRounds: last.totalRounds,
                segmentStart: last.end,
                segmentEnd: last.end,
                isFinished: true
            )
        }

        let segment = segments.first { time >= $0.start && time < $0.end } ?? segments[0]
        return ClockSnapshot(
            phase: segment.kind,
            remaining: max(0, segment.end.timeIntervalSince(time)),
            round: segment.round,
            totalRounds: segment.totalRounds,
            segmentStart: segment.start,
            segmentEnd: segment.end,
            isFinished: false
        )
    }

    mutating func pause(at now: Date) {
        guard pauseBegan == nil else { return }
        pauseBegan = now
    }

    mutating func resume(at now: Date) {
        guard let paused = pauseBegan else { return }
        let delta = now.timeIntervalSince(paused)
        if delta != 0 {
            for index in segments.indices where segments[index].end > paused {
                if segments[index].start > paused {
                    segments[index].start = segments[index].start.addingTimeInterval(delta)
                }
                segments[index].end = segments[index].end.addingTimeInterval(delta)
            }
            for index in cues.indices where cues[index].date > paused {
                cues[index].date = cues[index].date.addingTimeInterval(delta)
            }
        }
        pauseBegan = nil
    }

    func dueCues(after: Date, through now: Date) -> [Cue] {
        cues.filter { $0.date > after && $0.date <= now }.sorted { $0.date < $1.date }
    }

    mutating func refreshLocalizedCopy() {
        cues = Self.makeCues(segments: segments)
    }

    func futureBoundaryCues(after now: Date) -> [Cue] {
        cues.filter { $0.sound != .tick && $0.date > now }.sorted { $0.date < $1.date }
    }

    private static func makeCues(segments: [Segment]) -> [Cue] {
        var cues: [Cue] = []
        for (index, segment) in segments.enumerated() {
            cues.append(Cue(
                id: "seg-\(index)-start",
                date: segment.start,
                sound: startSound(segment.kind),
                title: title(segment.kind),
                body: body(segment)
            ))
            let duration = segment.end.timeIntervalSince(segment.start)
            let ticks: Bool
            switch segment.kind {
            case .work, .rest, .countdown: ticks = duration >= 5
            case .prepare, .finished: ticks = false
            }
            if ticks {
                for seconds in [3, 2, 1] {
                    let date = segment.end.addingTimeInterval(-TimeInterval(seconds))
                    if date > segment.start.addingTimeInterval(0.4) {
                        cues.append(Cue(
                            id: "seg-\(index)-tick-\(seconds)",
                            date: date,
                            sound: .tick,
                            title: title(segment.kind),
                            body: "\(seconds)"
                        ))
                    }
                }
            }
        }
        if let last = segments.last {
            cues.append(Cue(
                id: "session-end",
                date: last.end,
                sound: .end,
                title: AppLanguage.shared.text("phase.end"),
                body: last.kind == .countdown
                    ? AppLanguage.shared.text("detail.finished_countdown")
                    : AppLanguage.shared.text("detail.finished_session")
            ))
        }
        return cues
    }

    private static func startSound(_ kind: PhaseKind) -> SoundID {
        switch kind {
        case .prepare, .countdown: return .prepare
        case .work: return .work
        case .rest: return .rest
        case .finished: return .end
        }
    }

    private static func title(_ kind: PhaseKind) -> String {
        switch kind {
        case .prepare: return AppLanguage.shared.text("setting.prepare")
        case .work: return AppLanguage.shared.text("setting.work")
        case .rest: return AppLanguage.shared.text("setting.rest")
        case .countdown: return AppLanguage.shared.text("mode.countdown")
        case .finished: return AppLanguage.shared.text("phase.end")
        }
    }

    private static func body(_ segment: Segment) -> String {
        switch segment.kind {
        case .prepare: return AppLanguage.shared.text("detail.prepare")
        case .work, .rest: return AppLanguage.shared.text("detail.round \(segment.round) of \(segment.totalRounds)")
        case .countdown: return AppLanguage.shared.text("detail.countdown")
        case .finished: return AppLanguage.shared.text("detail.finished_session")
        }
    }
}

struct Lap: Equatable, Identifiable {
    var id: Int
    var split: TimeInterval
    var total: TimeInterval
}

struct StopwatchState: Equatable {
    var accumulated: TimeInterval = 0
    var runningSince: Date?
    var lastLapTotal: TimeInterval = 0
    var laps: [Lap] = []
    private var nextLapID = 1

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    mutating func start(at now: Date) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    mutating func pause(at now: Date) {
        guard let runningSince else { return }
        accumulated += now.timeIntervalSince(runningSince)
        self.runningSince = nil
    }

    mutating func lap(at now: Date) -> Lap? {
        guard runningSince != nil else { return nil }
        let total = elapsed(at: now)
        let lap = Lap(id: nextLapID, split: total - lastLapTotal, total: total)
        nextLapID += 1
        lastLapTotal = total
        laps.append(lap)
        return lap
    }

    mutating func reset() {
        self = StopwatchState()
    }
}

enum ClockFormat {
    static func clock(seconds: Int) -> String {
        let value = max(0, seconds)
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let secs = value % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    static func remaining(_ value: TimeInterval) -> String {
        if value <= 0 { return clock(seconds: 0) }
        return clock(seconds: Int(value + 0.999))
    }

    static func stopwatch(_ value: TimeInterval) -> String {
        let clamped = max(0, value)
        let centiseconds = Int((clamped * 100).rounded())
        let total = centiseconds / 100
        let hundredths = centiseconds % 100
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, minutes, seconds, hundredths)
        }
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }
}

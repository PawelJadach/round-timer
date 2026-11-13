import Foundation

private var failures = 0

private func expect(_ condition: Bool, _ message: String) {
    if !condition {
        failures += 1
        fputs("FAIL \(message)\n", stderr)
    }
}

private func expectClose(_ value: TimeInterval, _ target: TimeInterval, _ message: String) {
    expect(abs(value - target) < 0.001, "\(message): got \(value), want \(target)")
}

@main
enum TimelineTestRunner {
    static func main() {
        run()
    }
}

private func run() {
let start = Date(timeIntervalSince1970: 1_000_000)
var timeline = SessionTimeline.tabata(prepare: 10, work: 20, rest: 10, rounds: 3, start: start)
expect(timeline.segments.map(\.kind) == [.prepare, .work, .rest, .work, .rest, .work], "segment order")
expect(timeline.segments.last?.end == start.addingTimeInterval(90), "total length 90s")

let atStart = timeline.snapshot(at: start)
expect(atStart.phase == .prepare && atStart.remaining == 10, "opens in prepare")

let inWork = timeline.snapshot(at: start.addingTimeInterval(15))
expect(inWork.phase == .work && inWork.round == 1, "15s is work round 1")
expectClose(inWork.remaining, 15, "15s remaining in first work")

timeline.pause(at: start.addingTimeInterval(15))
let frozen = timeline.snapshot(at: start.addingTimeInterval(40))
expectClose(frozen.remaining, 15, "pause freezes remaining")
timeline.resume(at: start.addingTimeInterval(40))
let resumed = timeline.snapshot(at: start.addingTimeInterval(40))
expectClose(resumed.remaining, 15, "resume keeps the same remaining")
expect(timeline.snapshot(at: start.addingTimeInterval(55)).phase == .rest, "rest shifts with the pause")

let fresh = SessionTimeline.tabata(prepare: 0, work: 10, rest: 0, rounds: 2, start: start)
expect(fresh.segments.map(\.kind) == [.work, .work], "no rest and no prepare")
expect(fresh.snapshot(at: start.addingTimeInterval(10)).phase == .work && fresh.snapshot(at: start.addingTimeInterval(10)).round == 2, "second round starts on the boundary")
expect(fresh.snapshot(at: start.addingTimeInterval(20)).isFinished, "finished exactly at the end")

let countdown = SessionTimeline.countdown(seconds: 30, start: start)
expect(countdown.segments.count == 1 && countdown.segments[0].kind == .countdown, "countdown is one segment")
let countdownCues = countdown.cues.map(\.sound)
expect(countdownCues.contains(.prepare) && countdownCues.contains(.end) && countdownCues.filter { $0 == .tick }.count == 3, "countdown cues")

let due = countdown.dueCues(after: start.addingTimeInterval(-0.01), through: start)
expect(due.count == 1 && due[0].sound == .prepare, "opening cue is due at the start")
expect(countdown.dueCues(after: start, through: start.addingTimeInterval(9)).isEmpty, "same cue is not due twice")

var watch = StopwatchState()
watch.start(at: start)
expectClose(watch.elapsed(at: start.addingTimeInterval(10)), 10, "stopwatch runs")
_ = watch.lap(at: start.addingTimeInterval(10))
watch.pause(at: start.addingTimeInterval(12))
expectClose(watch.elapsed(at: start.addingTimeInterval(100)), 12, "pause holds the stopwatch")
expectClose(watch.laps[0].split, 10, "first lap split")
watch.start(at: start.addingTimeInterval(20))
expectClose(watch.elapsed(at: start.addingTimeInterval(25)), 17, "resume continues")

expect(ClockFormat.clock(seconds: 180) == "03:00", "3:00 format")
expect(ClockFormat.clock(seconds: 3661) == "1:01:01", "hour format")
expect(ClockFormat.remaining(10) == "00:10", "remaining 10")
expect(ClockFormat.remaining(0) == "00:00", "remaining zero")
expect(ClockFormat.stopwatch(12.34) == "00:12.34", "stopwatch hundredths")

if failures == 0 {
    print("timeline tests passed")
} else {
    fputs("\(failures) failed\n", stderr)
    exit(1)
}
}

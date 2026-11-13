import {
  canStart,
  createSession,
  dueCues,
  formatRemaining,
  lap,
  pauseSession,
  preview,
  resumeSession,
  snapshot,
  sparringTotalSeconds,
} from "./engine.js"

let failed = 0
function check(condition, message) {
  if (!condition) {
    failed += 1
    console.error("FAIL", message)
  }
}

const start = 1_000_000_000
const settings = { prepare: 10, work: 20, rest: 10, rounds: 2, countdown: 90 }
check(sparringTotalSeconds(settings) === 10 + 40 + 10, "total")

const session = createSession("sparring", settings, start)
check(session.segments.length === 4, `segments ${session.segments.length}`)
const midWork = snapshot(session, start + 15_000)
check(midWork.phase === "work" && midWork.text === "00:15", `mid work ${midWork.text}`)
const midRest = snapshot(session, start + 35_000)
check(midRest.phase === "rest" && midRest.remaining === 5_000, "mid rest")
check(snapshot(session, start + 60_000).finished, "finished")

pauseSession(session, start + 15_000)
check(snapshot(session, start + 100_000).text === "00:15", "pause freezes")
resumeSession(session, start + 25_000)
check(snapshot(session, start + 25_000).text === "00:15", "resume keeps remaining")
const shifted = session.cues.find((cue) => cue.id === "seg-3-start")
check(shifted.at === start + 50_000, "cue shifted")

const fresh = createSession("sparring", settings, start)
const first = dueCues(fresh, start - 1, start)
check(first.length === 1 && first[0].sound === "prepare", "opening cue")
check(dueCues(fresh, start, start + 10_000).some((cue) => cue.sound === "work"), "work cue")

const noRest = createSession("sparring", { ...settings, prepare: 0, rest: 0, work: 10 }, start)
check(noRest.segments.length === 2, "no rest")
check(noRest.cues.some((cue) => cue.id === "session-end" && cue.at === start + 20_000), "end cue")

const countdown = createSession("countdown", settings, start)
check(snapshot(countdown, start + 30_000).text === "01:00", `countdown ${snapshot(countdown, start + 30_000).text}`)

check(formatRemaining(180_000) === "03:00", "180")
check(formatRemaining(179_200) === "03:00", "179.2")
check(formatRemaining(179_000) === "02:59", "179")
check(formatRemaining(0) === "00:00", "zero")
check(formatRemaining(200) === "00:01", "fraction")

const watch = createSession("stopwatch", settings, start)
pauseSession(watch, start + 10_000)
check(snapshot(watch, start + 50_000).elapsed === 10_000, "stopwatch holds")
resumeSession(watch, start + 20_000)
check(snapshot(watch, start + 25_000).elapsed === 15_000, "stopwatch resumes")
lap(watch, start + 25_000)
check(watch.stopwatch.laps.length === 1 && watch.stopwatch.laps[0].split === 15_000, "lap")

check(preview("sparring", settings).phaseName === "PRZYGOTOWANIE", "preview")
check(canStart("countdown", { countdown: 4 }) === false, "short countdown")
check(canStart("stopwatch", settings), "stopwatch can start")

if (failed) {
  console.error(`${failed} failed`)
  process.exit(1)
}
console.log("OK")

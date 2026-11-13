import { lapDetail, roundDetail, t } from "./i18n.js"

export function formatClock(totalSeconds) {
  const value = Math.max(0, Math.floor(totalSeconds))
  const hours = Math.floor(value / 3600)
  const minutes = Math.floor((value % 3600) / 60)
  const seconds = value % 60
  if (hours > 0) return `${hours}:${pad(minutes)}:${pad(seconds)}`
  return `${pad(minutes)}:${pad(seconds)}`
}

export function formatRemaining(ms) {
  if (ms <= 0) return formatClock(0)
  return formatClock(Math.floor(ms / 1000 + 0.999))
}

export function formatStopwatch(ms) {
  const clamped = Math.max(0, ms)
  const total = Math.floor(clamped / 1000)
  const centis = Math.min(99, Math.floor((clamped % 1000) / 10))
  const hours = Math.floor(total / 3600)
  const minutes = Math.floor((total % 3600) / 60)
  const seconds = total % 60
  const tail = `${pad(minutes)}:${pad(seconds)}.${pad(centis)}`
  return hours > 0 ? `${hours}:${tail}` : tail
}

export function sparringTotalSeconds(settings) {
  return settings.prepare + settings.rounds * settings.work + Math.max(0, settings.rounds - 1) * settings.rest
}

export function createSession(kind, settings, now) {
  if (kind === "stopwatch") {
    return {
      kind,
      segments: [],
      cues: [],
      pauseBegan: null,
      stopwatch: { accumulated: 0, since: now, lastLap: 0, laps: [], nextId: 1 },
    }
  }
  const segments = kind === "countdown"
    ? countdownSegments(settings.countdown, now)
    : tabataSegments(settings, now)
  return { kind, segments, cues: makeCues(segments), pauseBegan: null, stopwatch: null }
}

export function snapshot(session, now) {
  const time = session.pauseBegan ?? now
  if (session.kind === "stopwatch") {
    const elapsed = stopwatchElapsed(session, time)
    return {
      phase: "stopwatch",
      remaining: 0,
      elapsed,
      round: 0,
      totalRounds: 0,
      finished: false,
      text: formatStopwatch(elapsed),
      phaseName: session.pauseBegan ? t("phasePause") : t("phaseStopwatch"),
      detail: session.stopwatch.laps.length ? lapDetail(session.stopwatch.laps.length) : t("detailStopwatch"),
      tint: "stopwatch",
    }
  }

  const last = session.segments[session.segments.length - 1]
  if (!last || time >= last.end) {
    return {
      phase: "finished",
      remaining: 0,
      elapsed: 0,
      round: last?.round ?? 0,
      totalRounds: last?.totalRounds ?? 0,
      finished: true,
      text: "00:00",
      phaseName: t("phaseEnd"),
      detail: session.kind === "countdown" ? t("detailFinishedCountdown") : t("detailFinishedSession"),
      tint: "end",
    }
  }

  const segment = session.segments.find((item) => time >= item.start && time < item.end) ?? session.segments[0]
  const remaining = Math.max(0, segment.end - time)
  return {
    phase: segment.kind,
    remaining,
    elapsed: 0,
    round: segment.round,
    totalRounds: segment.totalRounds,
    finished: false,
    text: formatRemaining(remaining),
    phaseName: phaseName(segment.kind),
    detail: detail(segment),
    tint: tint(segment.kind),
  }
}

export function pauseSession(session, now) {
  if (session.pauseBegan != null) return
  if (session.kind === "stopwatch" && session.stopwatch.since != null) {
    session.stopwatch.accumulated += now - session.stopwatch.since
    session.stopwatch.since = null
  }
  session.pauseBegan = now
}

export function resumeSession(session, now) {
  if (session.pauseBegan == null) return
  const delta = now - session.pauseBegan
  if (session.kind === "stopwatch") {
    session.stopwatch.since = now
  } else if (delta !== 0) {
    for (const segment of session.segments) {
      if (segment.end <= session.pauseBegan) continue
      if (segment.start > session.pauseBegan) segment.start += delta
      segment.end += delta
    }
    for (const cue of session.cues) {
      if (cue.at > session.pauseBegan) cue.at += delta
    }
  }
  session.pauseBegan = null
}

export function lap(session, now) {
  if (session.kind !== "stopwatch" || session.stopwatch.since == null) return null
  const total = stopwatchElapsed(session, now)
  const item = {
    id: session.stopwatch.nextId,
    split: total - session.stopwatch.lastLap,
    total,
  }
  session.stopwatch.nextId += 1
  session.stopwatch.lastLap = total
  session.stopwatch.laps.push(item)
  return item
}

export function dueCues(session, after, now) {
  return session.cues.filter((cue) => cue.at > after && cue.at <= now).sort((a, b) => a.at - b.at)
}

export function preview(kind, settings) {
  if (kind === "stopwatch") {
    return { text: "00:00.00", phaseName: t("phaseStopwatch"), detail: t("detailReady"), tint: "stopwatch" }
  }
  if (kind === "countdown") {
    return {
      text: formatClock(Math.max(0, settings.countdown)),
      phaseName: t("phaseCountdown"),
      detail: settings.countdown < 5 ? t("detailMinimum") : t("detailCountdown"),
      tint: "work",
    }
  }
  const opening = settings.prepare > 0 ? settings.prepare : settings.work
  return {
    text: formatClock(opening),
    phaseName: settings.prepare > 0 ? t("phasePrepare") : t("phaseWork"),
    detail: roundDetail(1, settings.rounds),
    tint: settings.prepare > 0 ? "prepare" : "work",
  }
}

export function canStart(kind, settings) {
  if (kind === "stopwatch") return true
  if (kind === "countdown") return settings.countdown >= 5
  return settings.work >= 5 && settings.rounds >= 1
}

function tabataSegments(settings, now) {
  const rounds = clamp(settings.rounds, 1, 30)
  const work = clamp(settings.work, 1, 3600)
  const rest = clamp(settings.rest, 0, 1800)
  const prepare = clamp(settings.prepare, 0, 120)
  const segments = []
  let cursor = now
  if (prepare > 0) {
    const end = cursor + prepare * 1000
    segments.push({ kind: "prepare", start: cursor, end, round: 1, totalRounds: rounds })
    cursor = end
  }
  for (let round = 1; round <= rounds; round += 1) {
    const workEnd = cursor + work * 1000
    segments.push({ kind: "work", start: cursor, end: workEnd, round, totalRounds: rounds })
    cursor = workEnd
    if (rest > 0 && round < rounds) {
      const restEnd = cursor + rest * 1000
      segments.push({ kind: "rest", start: cursor, end: restEnd, round, totalRounds: rounds })
      cursor = restEnd
    }
  }
  return segments
}

function countdownSegments(seconds, now) {
  const duration = Math.max(1, seconds)
  return [{ kind: "countdown", start: now, end: now + duration * 1000, round: 1, totalRounds: 1 }]
}

function makeCues(segments) {
  const cues = []
  segments.forEach((segment, index) => {
    cues.push({
      id: `seg-${index}-start`,
      at: segment.start,
      sound: startSound(segment.kind),
    })
    const duration = segment.end - segment.start
    if (duration >= 5000 && segment.kind !== "prepare") {
      for (const seconds of [3, 2, 1]) {
        const at = segment.end - seconds * 1000
        if (at > segment.start + 400) {
          cues.push({ id: `seg-${index}-tick-${seconds}`, at, sound: "tick" })
        }
      }
    }
  })
  const last = segments[segments.length - 1]
  if (last) cues.push({ id: "session-end", at: last.end, sound: "end" })
  return cues
}

function stopwatchElapsed(session, now) {
  const { accumulated, since } = session.stopwatch
  return accumulated + (since == null ? 0 : now - since)
}

function startSound(kind) {
  if (kind === "work") return "work"
  if (kind === "rest") return "rest"
  return "prepare"
}

function phaseName(kind) {
  if (kind === "prepare") return t("phasePrepare")
  if (kind === "work") return t("phaseWork")
  if (kind === "rest") return t("phaseRest")
  if (kind === "countdown") return t("phaseCountdown")
  return t("phaseEnd")
}

function detail(segment) {
  if (segment.kind === "prepare") return t("detailPrepare")
  if (segment.kind === "countdown") return t("detailCountdown")
  return roundDetail(segment.round, segment.totalRounds)
}

function tint(kind) {
  if (kind === "prepare") return "prepare"
  if (kind === "rest") return "rest"
  if (kind === "finished") return "end"
  return "work"
}

function pad(value) {
  return String(value).padStart(2, "0")
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value))
}

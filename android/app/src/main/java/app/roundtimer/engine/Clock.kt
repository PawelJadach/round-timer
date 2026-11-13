package app.roundtimer.engine

import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

enum class Mode { SPARRING, COUNTDOWN, STOPWATCH }

enum class SegmentKind { PREPARE, WORK, REST, COUNTDOWN }

enum class CueSound { PREPARE, WORK, REST, TICK, END }

enum class Tint { PREPARE, WORK, REST, END, STOPWATCH }

enum class PhaseLabel { PREPARE, WORK, REST, COUNTDOWN, STOPWATCH, END, PAUSE }

enum class PresetTitle { INTERVAL, SPARRING }

enum class CountdownSubtitle { HALF, ONE, THREE, FIVE, TEN }

sealed interface Detail {
    data object Ready : Detail
    data object CountingUp : Detail
    data class LapCount(val count: Int) : Detail
    data object MinimumFive : Detail
    data object Countdown : Detail
    data class Round(val round: Int, val total: Int) : Detail
    data object StartingSoon : Detail
    data object TimeUp : Detail
    data object SessionComplete : Detail
}

data class Settings(
    val prepare: Int = 10,
    val work: Int = 180,
    val rest: Int = 60,
    val rounds: Int = 5,
    val countdown: Int = 180,
)

data class SparringPreset(
    val title: PresetTitle,
    val detail: String,
    val prepare: Int,
    val work: Int,
    val rest: Int,
    val rounds: Int,
)

data class CountdownPreset(
    val title: String,
    val subtitle: CountdownSubtitle,
    val seconds: Int,
)

val SPARRING_PRESETS = listOf(
    SparringPreset(PresetTitle.INTERVAL, "30/15 × 10", 5, 30, 15, 10),
    SparringPreset(PresetTitle.SPARRING, "3:00 / 1:00 × 5", 10, 180, 60, 5),
)

val COUNTDOWN_PRESETS = listOf(
    CountdownPreset("0:30", CountdownSubtitle.HALF, 30),
    CountdownPreset("1:00", CountdownSubtitle.ONE, 60),
    CountdownPreset("3:00", CountdownSubtitle.THREE, 180),
    CountdownPreset("5:00", CountdownSubtitle.FIVE, 300),
    CountdownPreset("10:00", CountdownSubtitle.TEN, 600),
)

data class Segment(
    val kind: SegmentKind,
    var start: Long,
    var end: Long,
    val round: Int,
    val totalRounds: Int,
)

data class Cue(
    val id: String,
    var at: Long,
    val sound: CueSound,
)

data class LapMark(
    val id: Int,
    val split: Long,
    val total: Long,
)

class StopwatchState(
    var accumulated: Long = 0,
    var since: Long? = null,
    var lastLap: Long = 0,
    val laps: MutableList<LapMark> = mutableListOf(),
    var nextId: Int = 1,
)

class Session(
    val kind: Mode,
    val segments: MutableList<Segment>,
    val cues: MutableList<Cue>,
    var pauseBegan: Long?,
    val stopwatch: StopwatchState?,
)

data class Face(
    val phase: PhaseLabel,
    val text: String,
    val detail: Detail,
    val tint: Tint,
    val finished: Boolean,
)

fun formatClock(totalSeconds: Long): String {
    val value = max(0L, totalSeconds)
    val hours = value / 3600
    val minutes = (value % 3600) / 60
    val seconds = value % 60
    return if (hours > 0) "$hours:${pad(minutes)}:${pad(seconds)}" else "${pad(minutes)}:${pad(seconds)}"
}

fun formatRemaining(ms: Long): String {
    if (ms <= 0L) return formatClock(0)
    return formatClock(floor(ms / 1000.0 + 0.999).toLong())
}

fun formatStopwatch(ms: Long): String {
    val clamped = max(0L, ms)
    val total = (clamped / 1000).toInt()
    val centis = min(99, ((clamped % 1000) / 10).toInt())
    val hours = total / 3600
    val minutes = (total % 3600) / 60
    val seconds = total % 60
    val tail = "${pad(minutes)}:${pad(seconds)}.${pad(centis)}"
    return if (hours > 0) "$hours:$tail" else tail
}

fun sparringTotalSeconds(settings: Settings): Int {
    return settings.prepare + settings.rounds * settings.work + max(0, settings.rounds - 1) * settings.rest
}

fun createSession(kind: Mode, settings: Settings, now: Long): Session {
    if (kind == Mode.STOPWATCH) {
        return Session(
            kind = kind,
            segments = mutableListOf(),
            cues = mutableListOf(),
            pauseBegan = null,
            stopwatch = StopwatchState(since = now),
        )
    }
    val segments = if (kind == Mode.COUNTDOWN) {
        countdownSegments(settings.countdown, now)
    } else {
        tabataSegments(settings, now)
    }
    return Session(
        kind = kind,
        segments = segments.toMutableList(),
        cues = makeCues(segments).toMutableList(),
        pauseBegan = null,
        stopwatch = null,
    )
}

fun snapshot(session: Session, now: Long): Face {
    val time = session.pauseBegan ?: now
    if (session.kind == Mode.STOPWATCH) {
        val elapsed = stopwatchElapsed(session, time)
        val laps = session.stopwatch?.laps.orEmpty()
        return Face(
            phase = if (session.pauseBegan != null) PhaseLabel.PAUSE else PhaseLabel.STOPWATCH,
            text = formatStopwatch(elapsed),
            detail = if (laps.isNotEmpty()) Detail.LapCount(laps.size) else Detail.CountingUp,
            tint = Tint.STOPWATCH,
            finished = false,
        )
    }

    val last = session.segments.lastOrNull()
    if (last == null || time >= last.end) {
        return Face(
            phase = PhaseLabel.END,
            text = "00:00",
            detail = if (session.kind == Mode.COUNTDOWN) Detail.TimeUp else Detail.SessionComplete,
            tint = Tint.END,
            finished = true,
        )
    }

    val segment = session.segments.firstOrNull { time >= it.start && time < it.end } ?: session.segments.first()
    val remaining = max(0L, segment.end - time)
    return Face(
        phase = phaseLabel(segment.kind),
        text = formatRemaining(remaining),
        detail = detail(segment),
        tint = tint(segment.kind),
        finished = false,
    )
}

fun pauseSession(session: Session, now: Long) {
    if (session.pauseBegan != null) return
    val watch = session.stopwatch
    if (session.kind == Mode.STOPWATCH && watch?.since != null) {
        watch.accumulated += now - watch.since!!
        watch.since = null
    }
    session.pauseBegan = now
}

fun resumeSession(session: Session, now: Long) {
    val pausedAt = session.pauseBegan ?: return
    val delta = now - pausedAt
    if (session.kind == Mode.STOPWATCH) {
        session.stopwatch?.since = now
    } else if (delta != 0L) {
        for (segment in session.segments) {
            if (segment.end <= pausedAt) continue
            if (segment.start > pausedAt) segment.start += delta
            segment.end += delta
        }
        for (cue in session.cues) {
            if (cue.at > pausedAt) cue.at += delta
        }
    }
    session.pauseBegan = null
}

fun lap(session: Session, now: Long): LapMark? {
    val watch = session.stopwatch ?: return null
    if (session.kind != Mode.STOPWATCH || watch.since == null) return null
    val total = stopwatchElapsed(session, now)
    val item = LapMark(
        id = watch.nextId,
        split = total - watch.lastLap,
        total = total,
    )
    watch.nextId += 1
    watch.lastLap = total
    watch.laps.add(item)
    return item
}

fun dueCues(session: Session, after: Long, now: Long): List<Cue> {
    return session.cues.filter { it.at > after && it.at <= now }.sortedBy { it.at }
}

fun preview(kind: Mode, settings: Settings): Face {
    if (kind == Mode.STOPWATCH) {
        return Face(PhaseLabel.STOPWATCH, "00:00.00", Detail.Ready, Tint.STOPWATCH, finished = false)
    }
    if (kind == Mode.COUNTDOWN) {
        return Face(
            phase = PhaseLabel.COUNTDOWN,
            text = formatClock(max(0, settings.countdown).toLong()),
            detail = if (settings.countdown < 5) Detail.MinimumFive else Detail.Countdown,
            tint = Tint.WORK,
            finished = false,
        )
    }
    val opening = if (settings.prepare > 0) settings.prepare else settings.work
    val preparing = settings.prepare > 0
    return Face(
        phase = if (preparing) PhaseLabel.PREPARE else PhaseLabel.WORK,
        text = formatClock(opening.toLong()),
        detail = Detail.Round(1, settings.rounds),
        tint = if (preparing) Tint.PREPARE else Tint.WORK,
        finished = false,
    )
}

fun canStart(kind: Mode, settings: Settings): Boolean {
    if (kind == Mode.STOPWATCH) return true
    if (kind == Mode.COUNTDOWN) return settings.countdown >= 5
    return settings.work >= 5 && settings.rounds >= 1
}

private fun tabataSegments(settings: Settings, now: Long): List<Segment> {
    val rounds = clamp(settings.rounds, 1, 30)
    val work = clamp(settings.work, 1, 3600)
    val rest = clamp(settings.rest, 0, 1800)
    val prepare = clamp(settings.prepare, 0, 120)
    val segments = mutableListOf<Segment>()
    var cursor = now
    if (prepare > 0) {
        val end = cursor + prepare * 1000L
        segments.add(Segment(SegmentKind.PREPARE, cursor, end, 1, rounds))
        cursor = end
    }
    for (round in 1..rounds) {
        val workEnd = cursor + work * 1000L
        segments.add(Segment(SegmentKind.WORK, cursor, workEnd, round, rounds))
        cursor = workEnd
        if (rest > 0 && round < rounds) {
            val restEnd = cursor + rest * 1000L
            segments.add(Segment(SegmentKind.REST, cursor, restEnd, round, rounds))
            cursor = restEnd
        }
    }
    return segments
}

private fun countdownSegments(seconds: Int, now: Long): List<Segment> {
    val duration = max(1, seconds)
    return listOf(Segment(SegmentKind.COUNTDOWN, now, now + duration * 1000L, 1, 1))
}

private fun makeCues(segments: List<Segment>): List<Cue> {
    val cues = mutableListOf<Cue>()
    segments.forEachIndexed { index, segment ->
        cues.add(Cue("seg-$index-start", segment.start, startSound(segment.kind)))
        val duration = segment.end - segment.start
        if (duration >= 5000 && segment.kind != SegmentKind.PREPARE) {
            for (seconds in listOf(3, 2, 1)) {
                val at = segment.end - seconds * 1000L
                if (at > segment.start + 400) {
                    cues.add(Cue("seg-$index-tick-$seconds", at, CueSound.TICK))
                }
            }
        }
    }
    val last = segments.lastOrNull()
    if (last != null) cues.add(Cue("session-end", last.end, CueSound.END))
    return cues
}

private fun stopwatchElapsed(session: Session, now: Long): Long {
    val watch = session.stopwatch ?: return 0
    val running = watch.since?.let { now - it } ?: 0L
    return watch.accumulated + running
}

private fun startSound(kind: SegmentKind): CueSound {
    return when (kind) {
        SegmentKind.WORK -> CueSound.WORK
        SegmentKind.REST -> CueSound.REST
        SegmentKind.PREPARE, SegmentKind.COUNTDOWN -> CueSound.PREPARE
    }
}

private fun phaseLabel(kind: SegmentKind): PhaseLabel {
    return when (kind) {
        SegmentKind.PREPARE -> PhaseLabel.PREPARE
        SegmentKind.WORK -> PhaseLabel.WORK
        SegmentKind.REST -> PhaseLabel.REST
        SegmentKind.COUNTDOWN -> PhaseLabel.COUNTDOWN
    }
}

private fun detail(segment: Segment): Detail {
    return when (segment.kind) {
        SegmentKind.PREPARE -> Detail.StartingSoon
        SegmentKind.COUNTDOWN -> Detail.Countdown
        SegmentKind.WORK, SegmentKind.REST -> Detail.Round(segment.round, segment.totalRounds)
    }
}

private fun tint(kind: SegmentKind): Tint {
    return when (kind) {
        SegmentKind.PREPARE -> Tint.PREPARE
        SegmentKind.REST -> Tint.REST
        SegmentKind.WORK, SegmentKind.COUNTDOWN -> Tint.WORK
    }
}

private fun pad(value: Long): String = value.toString().padStart(2, '0')

private fun pad(value: Int): String = value.toString().padStart(2, '0')

private fun clamp(value: Int, minValue: Int, maxValue: Int): Int = min(maxValue, max(minValue, value))

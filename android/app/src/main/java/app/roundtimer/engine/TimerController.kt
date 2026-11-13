package app.roundtimer.engine

enum class RunState { IDLE, RUNNING, PAUSED, FINISHED }

enum class Nudge { PREPARE, WORK, REST, ROUNDS, COUNTDOWN_MINUTES, COUNTDOWN_SECONDS }

enum class Controls { START, RESET_PAUSE, LAP_PAUSE, RESET_RESUME, RESET_AGAIN }

data class Display(
    val mode: Mode,
    val runState: RunState,
    val face: Face,
    val showClock: Boolean,
    val chromeVisible: Boolean,
    val settingsVisible: Boolean,
    val laps: List<LapMark>,
    val controls: Controls,
    val canStart: Boolean,
    val sound: Boolean,
    val volume: Int,
    val settings: Settings,
)

/**
 * Same session state machine as the web app. A tick while the activity is
 * stopped still returns due cues, including the end bell.
 */
class TimerController(
    private val clock: () -> Long = { System.currentTimeMillis() },
) {
    var settings: Settings = Settings()
    var sound: Boolean = true
    var volume: Int = 80
    var mode: Mode = Mode.SPARRING
        private set
    var runState: RunState = RunState.IDLE
        private set
    var session: Session? = null
        private set
    var runMode: Mode? = null
        private set

    private var lastCueAt: Long = 0
    private var volumeTouched: Boolean = false

    fun display(): Display {
        val current = session
        val base = if (runState == RunState.IDLE || current == null) {
            preview(mode, settings)
        } else {
            snapshot(current, clock())
        }
        val face = if (runState == RunState.PAUSED) base.copy(phase = PhaseLabel.PAUSE) else base
        val laps = current?.stopwatch?.laps?.asReversed().orEmpty()
        val showLaps = runMode == Mode.STOPWATCH && laps.isNotEmpty() && runState != RunState.IDLE
        return Display(
            mode = mode,
            runState = runState,
            face = face,
            showClock = runState != RunState.IDLE || mode == Mode.STOPWATCH || mode == Mode.COUNTDOWN,
            chromeVisible = runState == RunState.IDLE,
            settingsVisible = runState == RunState.IDLE && mode != Mode.STOPWATCH,
            laps = if (showLaps) laps else emptyList(),
            controls = when (runState) {
                RunState.IDLE -> Controls.START
                RunState.RUNNING -> if (runMode == Mode.STOPWATCH) Controls.LAP_PAUSE else Controls.RESET_PAUSE
                RunState.PAUSED -> Controls.RESET_RESUME
                RunState.FINISHED -> Controls.RESET_AGAIN
            },
            canStart = canStart(mode, settings),
            sound = sound,
            volume = volume,
            settings = settings,
        )
    }

    fun start(): List<CueSound> {
        if (runState != RunState.IDLE) return emptyList()
        if (!canStart(mode, settings)) return emptyList()
        val now = clock()
        runMode = mode
        session = createSession(mode, settings, now)
        lastCueAt = now - 1
        runState = RunState.RUNNING
        return advance(now).sounds
    }

    fun pause(): List<CueSound> {
        if (runState != RunState.RUNNING || session == null) return emptyList()
        val now = clock()
        if (runMode != Mode.STOPWATCH) {
            val step = advance(now)
            if (step.finished) {
                runState = RunState.FINISHED
                return step.sounds
            }
            pauseSession(session!!, now)
            runState = RunState.PAUSED
            return step.sounds
        }
        pauseSession(session!!, now)
        runState = RunState.PAUSED
        return emptyList()
    }

    fun resume() {
        if (runState != RunState.PAUSED || session == null) return
        val now = clock()
        resumeSession(session!!, now)
        lastCueAt = now
        runState = RunState.RUNNING
    }

    fun reset() {
        runState = RunState.IDLE
        session = null
        runMode = null
    }

    fun again(): List<CueSound> {
        val modeToRun = runMode ?: return emptyList()
        reset()
        mode = modeToRun
        return start()
    }

    fun markLap(): List<CueSound> {
        val current = session ?: return emptyList()
        if (runState != RunState.RUNNING) return emptyList()
        if (lap(current, clock()) == null) return emptyList()
        return if (sound && volume > 0) listOf(CueSound.TICK) else emptyList()
    }

    fun selectMode(next: Mode) {
        if (runState == RunState.RUNNING || runState == RunState.PAUSED) return
        if (runState == RunState.FINISHED && next != mode) reset()
        mode = next
    }

    fun applySparringPreset(index: Int) {
        val preset = SPARRING_PRESETS.getOrNull(index) ?: return
        settings = settings.copy(
            prepare = preset.prepare,
            work = preset.work,
            rest = preset.rest,
            rounds = preset.rounds,
        )
    }

    fun applyCountdown(seconds: Int) {
        settings = settings.copy(countdown = seconds)
    }

    fun nudge(key: Nudge, delta: Int) {
        settings = when (key) {
            Nudge.PREPARE -> settings.copy(prepare = clamp(settings.prepare + delta, 0, 120))
            Nudge.WORK -> settings.copy(work = clamp(settings.work + delta, 5, 3600))
            Nudge.REST -> settings.copy(rest = clamp(settings.rest + delta, 0, 1800))
            Nudge.ROUNDS -> settings.copy(rounds = clamp(settings.rounds + delta, 1, 30))
            Nudge.COUNTDOWN_MINUTES -> settings.copy(countdown = clamp(settings.countdown + delta * 60, 0, 86400))
            Nudge.COUNTDOWN_SECONDS -> settings.copy(countdown = clamp(settings.countdown + delta, 0, 86400))
        }
    }

    fun step(key: Nudge): Int {
        return if (key == Nudge.ROUNDS || key == Nudge.COUNTDOWN_MINUTES) 1 else 5
    }

    fun updateSound(enabled: Boolean) {
        sound = enabled
    }

    fun noteVolumeTouch() {
        volumeTouched = true
    }

    fun updateVolume(value: Int) {
        volume = clamp(value, 0, 100)
    }

    /** True when releasing the slider should preview the work bell. */
    fun commitVolume(): Boolean {
        val touched = volumeTouched
        volumeTouched = false
        return touched && runState == RunState.IDLE && sound && volume > 0
    }

    fun tick(): List<CueSound> {
        if (runState != RunState.RUNNING || session == null) return emptyList()
        val step = advance(clock())
        if (step.finished) runState = RunState.FINISHED
        return step.sounds
    }

    private data class Step(val sounds: List<CueSound>, val finished: Boolean)

    private fun advance(now: Long): Step {
        val current = session ?: return Step(emptyList(), true)
        val cues = dueCues(current, lastCueAt, now)
        lastCueAt = now
        val sounds = mutableListOf<CueSound>()
        for (cue in cues) {
            val late = now - cue.at
            if (late < 1500 && cue.sound != CueSound.END) sounds.add(cue.sound)
            if (cue.sound == CueSound.END) {
                if (late < 1500) sounds.add(CueSound.END)
                return Step(sounds, snapshot(current, now).finished)
            }
        }
        return Step(sounds, snapshot(current, now).finished)
    }

    private fun clamp(value: Int, minValue: Int, maxValue: Int): Int {
        return kotlin.math.min(maxValue, kotlin.math.max(minValue, value))
    }
}

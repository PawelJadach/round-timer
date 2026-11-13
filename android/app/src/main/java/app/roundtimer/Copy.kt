package app.roundtimer

import android.content.Context
import app.roundtimer.engine.CountdownSubtitle
import app.roundtimer.engine.Detail
import app.roundtimer.engine.PhaseLabel
import app.roundtimer.engine.PresetTitle

fun Context.phaseText(phase: PhaseLabel): String = when (phase) {
    PhaseLabel.PREPARE -> getString(R.string.phase_prepare)
    PhaseLabel.WORK -> getString(R.string.phase_work)
    PhaseLabel.REST -> getString(R.string.phase_rest)
    PhaseLabel.COUNTDOWN -> getString(R.string.phase_countdown)
    PhaseLabel.STOPWATCH -> getString(R.string.phase_stopwatch)
    PhaseLabel.END -> getString(R.string.phase_end)
    PhaseLabel.PAUSE -> getString(R.string.phase_pause)
}

fun Context.detailText(detail: Detail): String = when (detail) {
    Detail.Ready -> getString(R.string.detail_ready)
    Detail.CountingUp -> getString(R.string.detail_counting)
    is Detail.LapCount -> getString(R.string.detail_lap, detail.count)
    Detail.MinimumFive -> getString(R.string.detail_min5)
    Detail.Countdown -> getString(R.string.detail_countdown)
    is Detail.Round -> getString(R.string.detail_round, detail.round, detail.total)
    Detail.StartingSoon -> getString(R.string.detail_prepare)
    Detail.TimeUp -> getString(R.string.detail_time_up)
    Detail.SessionComplete -> getString(R.string.detail_done)
}

fun Context.presetTitle(title: PresetTitle): String = when (title) {
    PresetTitle.TABATA -> getString(R.string.preset_tabata)
    PresetTitle.INTERVAL -> getString(R.string.preset_interval)
    PresetTitle.SPARRING -> getString(R.string.preset_sparring)
    PresetTitle.ROUND -> getString(R.string.preset_round)
}

fun Context.countdownSubtitle(subtitle: CountdownSubtitle): String = when (subtitle) {
    CountdownSubtitle.HALF -> getString(R.string.countdown_half)
    CountdownSubtitle.ONE -> getString(R.string.countdown_one)
    CountdownSubtitle.THREE -> getString(R.string.countdown_three)
    CountdownSubtitle.FIVE -> getString(R.string.countdown_five)
    CountdownSubtitle.TEN -> getString(R.string.countdown_ten)
}

package app.roundtimer

import app.roundtimer.engine.CueSound
import app.roundtimer.engine.Detail
import app.roundtimer.engine.Mode
import app.roundtimer.engine.Nudge
import app.roundtimer.engine.PhaseLabel
import app.roundtimer.engine.RunState
import app.roundtimer.engine.Settings
import app.roundtimer.engine.TimerController
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TimerControllerTest {
    @Test
    fun timingStepsAreFiveSecondsExceptRoundsAndMinutes() {
        val controller = TimerController { 0 }
        assertEquals(5, controller.step(Nudge.PREPARE))
        assertEquals(5, controller.step(Nudge.WORK))
        assertEquals(5, controller.step(Nudge.REST))
        assertEquals(5, controller.step(Nudge.COUNTDOWN_SECONDS))
        assertEquals(1, controller.step(Nudge.ROUNDS))
        assertEquals(1, controller.step(Nudge.COUNTDOWN_MINUTES))
        controller.nudge(Nudge.WORK, -5)
        assertEquals(175, controller.settings.work)
        controller.nudge(Nudge.WORK, 5)
        assertEquals(180, controller.settings.work)
    }

    @Test
    fun volumeDefaultsToEightyAndPreviewsOnlyWhileIdle() {
        val controller = TimerController { 0 }
        assertEquals(80, controller.volume)
        assertTrue(controller.sound)
        controller.noteVolumeTouch()
        controller.updateVolume(40)
        assertTrue(controller.commitVolume())
        controller.start()
        controller.noteVolumeTouch()
        controller.updateVolume(50)
        assertFalse(controller.commitVolume())
    }

    @Test
    fun chromeHidesForLivePausedAndFinished() {
        var now = 1_000L
        val controller = TimerController { now }
        controller.settings = Settings(prepare = 0, work = 5, rest = 0, rounds = 1, countdown = 30)
        assertTrue(controller.display().chromeVisible)
        controller.start()
        assertFalse(controller.display().chromeVisible)
        assertEquals(RunState.RUNNING, controller.runState)
        controller.pause()
        assertEquals(RunState.PAUSED, controller.runState)
        assertFalse(controller.display().chromeVisible)
        assertEquals(PhaseLabel.PAUSE, controller.display().face.phase)
        controller.resume()
        now += 5_000
        val sounds = controller.tick()
        assertTrue(sounds.contains(CueSound.END))
        assertEquals(RunState.FINISHED, controller.runState)
        assertFalse(controller.display().chromeVisible)
        assertEquals(Detail.SessionComplete, controller.display().face.detail)
    }

    @Test
    fun backgroundTicksStillPlayTheEndBell() {
        var now = 0L
        val controller = TimerController { now }
        controller.settings = Settings(prepare = 0, work = 5, rest = 5, rounds = 2)
        val heard = mutableListOf<CueSound>()
        heard += controller.start()
        while (controller.runState == RunState.RUNNING && now < 30_000) {
            now += 250
            heard += controller.tick()
        }
        assertEquals(RunState.FINISHED, controller.runState)
        assertEquals(CueSound.WORK, heard.first())
        assertTrue(heard.contains(CueSound.REST))
        assertEquals(CueSound.END, heard.last())
        assertTrue(heard.count { it == CueSound.TICK } >= 3)
    }

    @Test
    fun countdownUnderFiveSecondsDisablesStart() {
        val controller = TimerController { 0 }
        controller.selectMode(Mode.COUNTDOWN)
        controller.nudge(Nudge.COUNTDOWN_SECONDS, -175)
        assertEquals(5, controller.settings.countdown)
        controller.nudge(Nudge.COUNTDOWN_SECONDS, -5)
        assertEquals(0, controller.settings.countdown)
        assertFalse(controller.display().canStart)
        assertEquals(Detail.MinimumFive, controller.display().face.detail)
        assertTrue(controller.display().showClock)
        assertTrue(controller.start().isEmpty())
    }

    @Test
    fun sparringSetupHidesTheClockUntilStart() {
        val controller = TimerController { 0 }
        assertFalse(controller.display().showClock)
        assertTrue(controller.display().settingsVisible)
        controller.selectMode(Mode.STOPWATCH)
        assertTrue(controller.display().showClock)
        assertFalse(controller.display().settingsVisible)
    }

    @Test
    fun modeSwitchWhileRunningIsIgnored() {
        val controller = TimerController { 0 }
        controller.start()
        controller.selectMode(Mode.COUNTDOWN)
        assertEquals(Mode.SPARRING, controller.mode)
    }
}

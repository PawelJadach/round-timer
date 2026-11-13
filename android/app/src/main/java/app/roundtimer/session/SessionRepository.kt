package app.roundtimer.session

import android.app.Application
import android.content.Intent
import androidx.core.content.ContextCompat
import app.roundtimer.audio.CuePlayer
import app.roundtimer.data.Prefs
import app.roundtimer.engine.CueSound
import app.roundtimer.engine.Display
import app.roundtimer.engine.Mode
import app.roundtimer.engine.Nudge
import app.roundtimer.engine.RunState
import app.roundtimer.engine.TimerController
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class SessionRepository(
    private val app: Application,
    private val prefs: Prefs,
    private val player: CuePlayer,
) {
    private val controller = TimerController()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val _state = MutableStateFlow(controller.display())
    val state: StateFlow<Display> = _state
    private var ticker: Job? = null
    private var shutdownJob: Job? = null
    private var service: SessionService? = null

    init {
        controller.settings = prefs.loadSettings()
        controller.sound = prefs.loadSound()
        controller.volume = prefs.loadVolume()
        publish()
    }

    fun bind(service: SessionService) {
        this.service = service
    }

    fun unbind(service: SessionService) {
        if (this.service === service) this.service = null
    }

    fun wantsForeground(): Boolean {
        return controller.runState == RunState.RUNNING || controller.runState == RunState.PAUSED
    }

    fun start() = arm(controller.start())

    fun again() {
        shutdownJob?.cancel()
        arm(controller.again())
    }

    fun pause() {
        val sounds = controller.pause()
        player.playAll(sounds, controller.sound, controller.volume)
        ticker?.cancel()
        publish()
        if (controller.runState == RunState.FINISHED) scheduleStop(sounds.contains(CueSound.END))
    }

    fun resume() {
        controller.resume()
        publish()
        if (controller.runState == RunState.RUNNING) {
            player.startKeepAlive()
            ContextCompat.startForegroundService(app, Intent(app, SessionService::class.java))
            ensureTicker()
        }
    }

    fun reset() {
        shutdownJob?.cancel()
        ticker?.cancel()
        controller.reset()
        player.stopKeepAlive()
        publish()
        service?.shutdown()
    }

    fun lap() {
        val sounds = controller.markLap()
        player.playAll(sounds, controller.sound, controller.volume)
        publish()
    }

    fun selectMode(mode: Mode) {
        controller.selectMode(mode)
        publish()
    }

    fun preset(index: Int) {
        controller.applySparringPreset(index)
        prefs.saveSettings(controller.settings)
        publish()
    }

    fun countdown(seconds: Int) {
        controller.applyCountdown(seconds)
        prefs.saveSettings(controller.settings)
        publish()
    }

    fun nudge(key: Nudge, delta: Int) {
        controller.nudge(key, delta)
        prefs.saveSettings(controller.settings)
        publish()
    }

    fun step(key: Nudge): Int = controller.step(key)

    fun toggleSound() {
        controller.updateSound(!controller.sound)
        prefs.saveSound(controller.sound)
        publish()
    }

    fun volumeChanging(value: Int) {
        controller.noteVolumeTouch()
        controller.updateVolume(value)
        prefs.saveVolume(controller.volume)
        publish()
    }

    fun volumeCommitted() {
        if (controller.commitVolume()) {
            player.playAll(listOf(CueSound.WORK), true, controller.volume)
        }
    }

    fun refreshNotification() {
        service?.render(state.value)
    }

    private fun arm(sounds: List<CueSound>) {
        publish()
        if (controller.runState != RunState.RUNNING) return
        player.startKeepAlive()
        player.playAll(sounds, controller.sound, controller.volume)
        ContextCompat.startForegroundService(app, Intent(app, SessionService::class.java))
        ensureTicker()
    }

    private fun ensureTicker() {
        if (ticker?.isActive == true) return
        ticker = scope.launch {
            while (isActive && controller.runState == RunState.RUNNING) {
                val sounds = controller.tick()
                player.playAll(sounds, controller.sound, controller.volume)
                publish()
                if (controller.runState == RunState.FINISHED) {
                    scheduleStop(sounds.contains(CueSound.END))
                    break
                }
                delay(16)
            }
        }
    }

    private fun scheduleStop(playedEnd: Boolean) {
        shutdownJob?.cancel()
        shutdownJob = scope.launch {
            delay(if (playedEnd) 2200 else 400)
            if (controller.runState == RunState.FINISHED) {
                player.stopKeepAlive()
                service?.shutdown()
            }
        }
    }

    private fun publish() {
        _state.value = controller.display()
    }
}

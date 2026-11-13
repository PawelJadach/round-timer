package app.roundtimer.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import app.roundtimer.RoundTimerApp
import app.roundtimer.engine.Mode
import app.roundtimer.engine.Nudge

class TimerViewModel(app: Application) : AndroidViewModel(app) {
    private val repository = (app as RoundTimerApp).repository
    val state = repository.state

    fun start() = repository.start()
    fun pause() = repository.pause()
    fun resume() = repository.resume()
    fun reset() = repository.reset()
    fun again() = repository.again()
    fun lap() = repository.lap()
    fun selectMode(mode: Mode) = repository.selectMode(mode)
    fun preset(index: Int) = repository.preset(index)
    fun countdown(seconds: Int) = repository.countdown(seconds)
    fun nudge(key: Nudge, direction: Int) = repository.nudge(key, direction * repository.step(key))
    fun toggleSound() = repository.toggleSound()
    fun onVolume(value: Float) = repository.volumeChanging(value.toInt())
    fun onVolumeCommit() = repository.volumeCommitted()
    fun refreshNotification() = repository.refreshNotification()
}

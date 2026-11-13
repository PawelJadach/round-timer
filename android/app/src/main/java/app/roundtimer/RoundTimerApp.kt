package app.roundtimer

import android.app.Application
import app.roundtimer.audio.CuePlayer
import app.roundtimer.data.Prefs
import app.roundtimer.session.SessionRepository

class RoundTimerApp : Application() {
    lateinit var repository: SessionRepository
        private set

    override fun onCreate() {
        super.onCreate()
        val prefs = Prefs(this)
        repository = SessionRepository(this, prefs, CuePlayer(this))
    }
}

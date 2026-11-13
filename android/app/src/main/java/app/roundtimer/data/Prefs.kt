package app.roundtimer.data

import android.content.Context
import app.roundtimer.engine.Settings
import java.util.Locale

class Prefs(context: Context) {
    private val storage = context.applicationContext.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    fun loadSettings(): Settings = Settings(
        prepare = storage.getInt(PREPARE, 10),
        work = storage.getInt(WORK, 180),
        rest = storage.getInt(REST, 60),
        rounds = storage.getInt(ROUNDS, 5),
        countdown = storage.getInt(COUNTDOWN, 180),
    )

    fun saveSettings(settings: Settings) {
        storage.edit()
            .putInt(PREPARE, settings.prepare)
            .putInt(WORK, settings.work)
            .putInt(REST, settings.rest)
            .putInt(ROUNDS, settings.rounds)
            .putInt(COUNTDOWN, settings.countdown)
            .apply()
    }

    fun loadSound(): Boolean = storage.getBoolean(SOUND, true)

    fun saveSound(enabled: Boolean) {
        storage.edit().putBoolean(SOUND, enabled).apply()
    }

    fun loadVolume(): Int = storage.getInt(VOLUME, 80).coerceIn(0, 100)

    fun saveVolume(volume: Int) {
        storage.edit().putInt(VOLUME, volume.coerceIn(0, 100)).apply()
    }

    /** Null follows the system language. "en" or "pl" is an explicit choice. */
    fun language(): String? = storage.getString(LANGUAGE, null)

    fun setLanguage(code: String) {
        storage.edit().putString(LANGUAGE, code).apply()
    }

    fun resolvedLanguage(): String {
        val saved = language()
        if (saved == "pl" || saved == "en") return saved
        return if (Locale.getDefault().language == "pl") "pl" else "en"
    }

    companion object {
        private const val NAME = "roundtimer"
        private const val PREPARE = "prepare"
        private const val WORK = "work"
        private const val REST = "rest"
        private const val ROUNDS = "rounds"
        private const val COUNTDOWN = "countdown"
        private const val SOUND = "sound"
        private const val VOLUME = "volume"
        private const val LANGUAGE = "language"
    }
}

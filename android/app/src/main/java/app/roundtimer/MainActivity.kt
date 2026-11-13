package app.roundtimer

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import app.roundtimer.data.Prefs
import app.roundtimer.engine.RunState
import app.roundtimer.ui.RoundTimerTheme
import app.roundtimer.ui.TimerScreen
import app.roundtimer.ui.TimerViewModel

class MainActivity : ComponentActivity() {
    private val notifications = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { }

    override fun attachBaseContext(newBase: android.content.Context) {
        super.attachBaseContext(newBase.withAppLocale())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        WindowCompat.getInsetsController(window, window.decorView).isAppearanceLightStatusBars = false
        setContent {
            val model: TimerViewModel = viewModel()
            val state by model.state.collectAsState()
            DisposableEffect(state.runState) {
                if (state.runState == RunState.RUNNING) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                onDispose { window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
            }
            RoundTimerTheme {
                TimerScreen(
                    state = state,
                    language = if (resources.configuration.locales[0].language == "pl") "pl" else "en",
                    onLanguage = { code ->
                        Prefs(this).setLanguage(code)
                        model.refreshNotification()
                        recreate()
                    },
                    onStart = {
                        askNotifications()
                        model.start()
                    },
                    onPause = model::pause,
                    onResume = model::resume,
                    onReset = model::reset,
                    onAgain = model::again,
                    onLap = model::lap,
                    onMode = model::selectMode,
                    onPreset = model::preset,
                    onCountdown = model::countdown,
                    onNudge = model::nudge,
                    onToggleSound = model::toggleSound,
                    onVolume = model::onVolume,
                    onVolumeCommit = model::onVolumeCommit,
                )
            }
        }
    }

    private fun askNotifications() {
        if (Build.VERSION.SDK_INT < 33) return
        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
        if (granted != PackageManager.PERMISSION_GRANTED) {
            notifications.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
}

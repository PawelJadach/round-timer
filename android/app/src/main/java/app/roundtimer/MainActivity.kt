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
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import android.content.res.Configuration
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
            val prefs = remember { Prefs(applicationContext) }
            var languageTick by remember { mutableIntStateOf(0) }
            val language = remember(languageTick) { prefs.resolvedLanguage() }
            val usesManualLanguage = remember(languageTick) { prefs.usesManualLanguage() }
            val localizedContext = remember(language) { applicationContext.withAppLocale(language) }
            val localizedConfiguration =
                remember(localizedContext) { Configuration(localizedContext.resources.configuration) }
            var settingsOpen by remember { mutableStateOf(false) }

            DisposableEffect(state.runState) {
                if (state.runState == RunState.RUNNING) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                onDispose { window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
            }

            CompositionLocalProvider(
                LocalContext provides localizedContext,
                LocalConfiguration provides localizedConfiguration,
            ) {
                RoundTimerTheme {
                    TimerScreen(
                        state = state,
                        language = language,
                        usesManualLanguage = usesManualLanguage,
                        settingsOpen = settingsOpen,
                        onSettingsOpen = { settingsOpen = it },
                        onLanguage = { code ->
                            prefs.setLanguage(code)
                            applyAppLanguage(prefs)
                            languageTick++
                            model.refreshNotification()
                        },
                        onFollowSystemLanguage = {
                            prefs.followSystemLanguage()
                            applyAppLanguage(prefs)
                            languageTick++
                            model.refreshNotification()
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
                        onNudge = model::nudge,
                        onToggleSound = model::toggleSound,
                        onVolume = model::onVolume,
                        onVolumeCommit = model::onVolumeCommit,
                    )
                }
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
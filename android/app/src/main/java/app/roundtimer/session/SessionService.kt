package app.roundtimer.session

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import app.roundtimer.MainActivity
import app.roundtimer.R
import app.roundtimer.RoundTimerApp
import app.roundtimer.detailText
import app.roundtimer.engine.Display
import app.roundtimer.engine.RunState
import app.roundtimer.phaseText
import app.roundtimer.withAppLocale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class SessionService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var watch: Job? = null
    private var mediaSession: MediaSessionCompat? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var stopping = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val session = MediaSessionCompat(this, "RoundTimer")
        session.setCallback(object : MediaSessionCompat.Callback() {})
        session.isActive = true
        mediaSession = session
        val power = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "roundtimer:session").apply {
            setReferenceCounted(false)
            acquire(24 * 60 * 60 * 1000L)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val repository = repository()
        if (repository.wantsForeground()) stopping = false
        val notification = buildNotification(repository.state.value)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        repository.bind(this)
        if (watch == null) {
            watch = scope.launch {
                var lastKey = ""
                repository.state.collect { state ->
                    val key = "${state.runState}:${state.face.phase}:${state.face.text.take(5)}"
                    if (key == lastKey) return@collect
                    lastKey = key
                    render(state)
                }
            }
        }
        if (!repository.wantsForeground()) shutdown()
        return START_STICKY
    }

    fun render(state: Display) {
        if (stopping) return
        updatePlayback(state)
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(state))
    }

    fun shutdown() {
        if (stopping) return
        stopping = true
        watch?.cancel()
        repository().unbind(this)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        watch?.cancel()
        repository().unbind(this)
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    private fun repository(): SessionRepository = (application as RoundTimerApp).repository

    private fun buildNotification(state: Display): Notification {
        val localized = withAppLocale()
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            localized.getString(R.string.channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = localized.getString(R.string.channel_description)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val phase = localized.phaseText(state.face.phase)
        val detail = localized.detailText(state.face.detail)
        val session = mediaSession
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(phase)
            .setContentText("${state.face.text} · $detail")
            .setOngoing(state.runState == RunState.RUNNING || state.runState == RunState.PAUSED)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setColor(0xFFFF4E2E.toInt())
            .setContentIntent(open)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(session?.sessionToken),
            )
            .build()
    }

    private fun updatePlayback(state: Display) {
        val playing = state.runState == RunState.RUNNING
        val playback = if (playing) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        mediaSession?.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(0)
                .setState(playback, 0L, if (playing) 1f else 0f)
                .build(),
        )
        val localized = withAppLocale()
        mediaSession?.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, localized.phaseText(state.face.phase))
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, state.face.text)
                .build(),
        )
    }

    companion object {
        private const val CHANNEL_ID = "round_timer_session"
        private const val NOTIFICATION_ID = 42
    }
}

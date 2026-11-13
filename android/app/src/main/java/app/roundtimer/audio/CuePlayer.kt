package app.roundtimer.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.SoundPool
import android.os.Handler
import android.os.Looper
import app.roundtimer.R
import app.roundtimer.engine.CueSound
import kotlin.math.sin

/**
 * Ring bell for work, rest, and the end of the session. Prepare and the
 * 3-2-1 tick are short tones. A silent loop keeps the media-playback
 * foreground service alive between cues.
 */
class CuePlayer(context: Context) {
    private val app = context.applicationContext
    private val audio = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val handler = Handler(Looper.getMainLooper())
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()
    private val pool = SoundPool.Builder()
        .setMaxStreams(4)
        .setAudioAttributes(attributes)
        .build()
    private val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        .setAudioAttributes(attributes)
        .build()
    private val bellId = pool.load(app, R.raw.bell, 1)
    private val prepareId = pool.load(app, R.raw.prepare, 1)
    private val tickId = pool.load(app, R.raw.tick, 1)
    private var loaded = 0
    private val waiting = ArrayDeque<Pending>()

    @Volatile private var keepAliveRunning = false
    private var keepAliveThread: Thread? = null
    private var keepAliveTrack: AudioTrack? = null

    init {
        pool.setOnLoadCompleteListener { _, _, status ->
            if (status == 0) loaded += 1
            if (loaded >= 3) {
                val pending = waiting.toList()
                waiting.clear()
                pending.forEach { playNow(it) }
            }
        }
    }

    fun playAll(sounds: List<CueSound>, enabled: Boolean, volume: Int) {
        if (!enabled || volume <= 0 || sounds.isEmpty()) return
        val level = volume.coerceIn(0, 100) / 100f
        sounds.forEach { sound ->
            val pending = Pending(sound, level)
            if (loaded < 3) waiting.add(pending) else playNow(pending)
        }
    }

    fun startKeepAlive() {
        if (keepAliveThread?.isAlive == true) return
        keepAliveRunning = true
        keepAliveThread = Thread({
            try {
                runKeepAlive()
            } catch (_: RuntimeException) {
                keepAliveRunning = false
            }
        }, "roundtimer-keepalive").also { it.start() }
    }

    fun stopKeepAlive() {
        keepAliveRunning = false
        try {
            keepAliveTrack?.pause()
            keepAliveTrack?.flush()
        } catch (_: RuntimeException) {
        }
        keepAliveThread?.join(500)
        keepAliveThread = null
    }

    private fun playNow(pending: Pending) {
        val id = when (pending.sound) {
            CueSound.WORK, CueSound.REST, CueSound.END -> bellId
            CueSound.PREPARE -> prepareId
            CueSound.TICK -> tickId
        }
        handler.removeCallbacks(releaseFocus)
        audio.requestAudioFocus(focus)
        pool.play(id, pending.volume, pending.volume, 1, 0, 1f)
        handler.postDelayed(releaseFocus, holdFor(pending.sound))
    }

    private val releaseFocus = Runnable {
        audio.abandonAudioFocusRequest(focus)
    }

    private fun holdFor(sound: CueSound): Long {
        return when (sound) {
            CueSound.WORK, CueSound.REST, CueSound.END -> 2000L
            CueSound.PREPARE -> 400L
            CueSound.TICK -> 160L
        }
    }

    private fun runKeepAlive() {
        val rate = 44100
        val min = AudioTrack.getMinBufferSize(
            rate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        ).coerceAtLeast(rate / 5)
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(rate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(min * 2)
            .build()
        keepAliveTrack = track
        track.play()
        val frames = min / 2
        val buffer = ShortArray(frames) { index ->
            (sin(2.0 * Math.PI * 30.0 * index / rate) * 2.0).toInt().toShort()
        }
        while (keepAliveRunning) {
            val wrote = track.write(buffer, 0, buffer.size)
            if (wrote < 0) break
        }
        track.pause()
        track.flush()
        track.release()
        if (keepAliveTrack === track) keepAliveTrack = null
    }

    private data class Pending(val sound: CueSound, val volume: Float)
}

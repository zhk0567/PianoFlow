package com.pianoflow.android.practice

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.SoundPool
import android.util.Log
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Piano sample player (assets/audio/piano/n{midi}.wav) — Windows 同款采样。
 * Warmup is silent (no audible PCM) to avoid ghost notes on practice open.
 */
class TonePlayer(context: Context) {
    private val app = context.applicationContext
    private val pool: SoundPool = SoundPool.Builder()
        .setMaxStreams(12)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build(),
        )
        .build()
    private val soundIds = ConcurrentHashMap<Int, Int>()
    private val ready = AtomicBoolean(false)
    private val exec = Executors.newSingleThreadExecutor()
    @Volatile var masterVolume: Float = 0.85f

    init {
        exec.execute { preloadQuiet() }
    }

    /** Load samples off the UI thread; never plays during warmup. */
    private fun preloadQuiet() {
        try {
            var loaded = 0
            for (midi in 21..108) {
                val path = "audio/piano/n$midi.wav"
                try {
                    app.assets.openFd(path).use { afd: AssetFileDescriptor ->
                        val id = pool.load(afd, 1)
                        soundIds[midi] = id
                        loaded++
                    }
                } catch (e: Exception) {
                    Log.w("PianoFlow/Audio", "missing $path: $e")
                }
            }
            ready.set(true)
            Log.i("PianoFlow/Audio", "piano samples ready count=$loaded")
        } catch (e: Exception) {
            Log.e("PianoFlow/Audio", "preload failed: $e")
        }
    }

    fun playMidi(midi: Int, _ms: Int = 0) {
        val m = midi.coerceIn(21, 108)
        exec.execute {
            if (!ready.get()) {
                // Avoid audible sine fallback — wait briefly then skip if still cold
                Thread.sleep(30)
            }
            val sid = soundIds[m]
            if (sid == null) {
                Log.w("PianoFlow/Audio", "no sample for midi=$m")
                return@execute
            }
            try {
                pool.play(sid, masterVolume, masterVolume, 1, 0, 1f)
            } catch (e: Exception) {
                Log.e("PianoFlow/Audio", "play failed midi=$m: $e")
            }
        }
    }

    fun shutdown() {
        try {
            pool.release()
        } catch (_: Exception) {
        }
        exec.shutdownNow()
    }
}

package com.pianoflow.android.practice

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

class MicPitchTracker(
    private val onMidis: (Set<Int>) -> Unit,
    private val onError: (String) -> Unit,
    private val onPcm16: ((ShortArray, Int) -> Unit)? = null,
) {
    private val running = AtomicBoolean(false)
    private var thread: Thread? = null

    fun start() {
        if (!running.compareAndSet(false, true)) return
        thread = Thread({
            val sr = 22050
            val minBuf = AudioRecord.getMinBufferSize(
                sr,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            val bufSize = minBuf.coerceAtLeast(4096)
            val record = try {
                AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    sr,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufSize,
                )
            } catch (e: SecurityException) {
                onError("没有麦克风权限，请在系统设置中允许 PianoFlow 使用麦克风。")
                running.set(false)
                return@Thread
            } catch (e: Exception) {
                Log.e("PianoFlow/Pitch", "AudioRecord: $e")
                onError("麦克风初始化失败（详情见 logcat [PianoFlow/Pitch]）")
                running.set(false)
                return@Thread
            }
            if (record.state != AudioRecord.STATE_INITIALIZED) {
                onError("麦克风不可用，请检查系统权限与其它占用。")
                running.set(false)
                record.release()
                return@Thread
            }
            val buf = ShortArray(1024)
            record.startRecording()
            Log.i("PianoFlow/Pitch", "pitch stream started")
            try {
                while (running.get()) {
                    val n = record.read(buf, 0, buf.size)
                    if (n > 0) {
                        onPcm16?.invoke(buf, n)
                        val slice = if (n == buf.size) buf else buf.copyOf(n)
                        val poly = PolyYinPitch.midisFromPcm16(slice, sr)
                        if (poly.isNotEmpty()) {
                            onMidis(poly)
                        } else {
                            val midi = YinPitch.midiFromPcm16(slice, sr)
                            if (midi != null) onMidis(setOf(midi))
                        }
                    }
                }
            } finally {
                try { record.stop() } catch (_: Exception) {}
                record.release()
                Log.i("PianoFlow/Pitch", "pitch stream stopped")
            }
        }, "pf-pitch").also { it.start() }
    }

    fun stop() {
        running.set(false)
        thread = null
    }
}

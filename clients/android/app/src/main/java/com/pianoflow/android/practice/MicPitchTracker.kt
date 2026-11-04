package com.pianoflow.android.practice

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Mic → Basic Pitch (primary) → Poly-YIN / YIN fallback.
 * Emits note-on edges + frame MIDI sets with capture timestamps.
 */
class MicPitchTracker(
    private val context: Context,
    private val onNoteOns: (Set<Int>, Long) -> Unit,
    private val onFrame: (Set<Int>, Long, Boolean) -> Unit,
    private val onError: (String) -> Unit,
    private val onEngine: ((String) -> Unit)? = null,
    private val onPcm16: ((ShortArray, Int) -> Unit)? = null,
    private val priorMidis: () -> Set<Int> = { emptySet() },
) {
    private val running = AtomicBoolean(false)
    private var thread: Thread? = null
    @Volatile var engineLabel: String = "…"
        private set

    fun start() {
        if (!running.compareAndSet(false, true)) return
        thread = Thread({
            val sr = BasicPitchEstimator.SAMPLE_RATE // 22050
            val bp = BasicPitchEstimator.create(context)
            val edges = PitchEdgeTracker()
            val onset = OnsetFluxDetector()
            engineLabel = if (bp != null) "Basic Pitch（多音）" else "Poly-YIN / YIN"
            onEngine?.invoke(engineLabel)
            Log.i(TAG, "engine=$engineLabel")

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
                bp?.close()
                return@Thread
            } catch (e: Exception) {
                Log.e(TAG, "AudioRecord: $e")
                onError("麦克风初始化失败（详情见 logcat [PianoFlow/Pitch]）")
                running.set(false)
                bp?.close()
                return@Thread
            }
            if (record.state != AudioRecord.STATE_INITIALIZED) {
                onError("麦克风不可用，请检查系统权限与其它占用。")
                running.set(false)
                record.release()
                bp?.close()
                return@Thread
            }

            val ring = FloatArray(BasicPitchEstimator.AUDIO_N_SAMPLES)
            var ringFill = 0
            var ringWrite = 0
            val hop = (sr * 0.030).toInt().coerceAtLeast(512) // ~30ms
            var sinceHop = 0
            val yinAccum = ShortArray(4096)
            var yinN = 0
            var busy = false

            val buf = ShortArray(1024)
            record.startRecording()
            Log.i(TAG, "pitch stream started hop=$hop")
            try {
                while (running.get()) {
                    val n = record.read(buf, 0, buf.size)
                    if (n <= 0) continue
                    onPcm16?.invoke(buf, n)

                    for (i in 0 until n) {
                        val s = buf[i] / 32768f
                        ring[ringWrite] = s
                        ringWrite = (ringWrite + 1) % ring.size
                        if (ringFill < ring.size) ringFill++
                        sinceHop++
                        if (yinN < yinAccum.size) {
                            yinAccum[yinN++] = buf[i]
                        } else {
                            val keep = yinAccum.size / 2
                            System.arraycopy(yinAccum, yinN - keep, yinAccum, 0, keep)
                            yinN = keep
                            yinAccum[yinN++] = buf[i]
                        }
                    }

                    if (sinceHop < hop) continue
                    sinceHop = 0
                    if (busy) continue
                    busy = true
                    val captureAt = System.currentTimeMillis()
                    try {
                        val midis = estimateHop(
                            bp = bp,
                            ring = ring,
                            ringWrite = ringWrite,
                            ringFill = ringFill,
                            yinAccum = yinAccum,
                            yinN = yinN,
                            sr = sr,
                        )
                        val onsetSamples = snapshotLast(ring, ringWrite, ringFill, 2048)
                        val onsetHit = midis.isNotEmpty() && onset.push(onsetSamples)
                        if (onsetHit) {
                            edges.clearEmitted(midis)
                        }
                        val noteOns = edges.update(midis)
                        if (noteOns.isNotEmpty()) onNoteOns(noteOns, captureAt)
                        onFrame(edges.lockedMidis().ifEmpty { midis }, captureAt, onsetHit)
                    } finally {
                        busy = false
                    }
                }
            } finally {
                try { record.stop() } catch (_: Exception) {}
                record.release()
                bp?.close()
                Log.i(TAG, "pitch stream stopped")
            }
        }, "pf-pitch").also { it.start() }
    }

    fun stop() {
        running.set(false)
        thread = null
    }

    private fun estimateHop(
        bp: BasicPitchEstimator?,
        ring: FloatArray,
        ringWrite: Int,
        ringFill: Int,
        yinAccum: ShortArray,
        yinN: Int,
        sr: Int,
    ): Set<Int> {
        if (bp != null && ringFill > 512) {
            val snapshot = snapshotRing(ring, ringWrite, ringFill)
            if (rms(snapshot) < RMS_GATE) return emptySet()
            val prior = priorMidis().let { if (it.isEmpty()) null else it }
            val fromBp = bp.estimateActiveMidi(snapshot, priorMidis = prior)
            if (fromBp.isNotEmpty()) return fromBp
        }
        return fallbackYin(yinAccum, yinN, sr)
    }

    private fun fallbackYin(yinAccum: ShortArray, yinN: Int, sr: Int): Set<Int> {
        if (yinN <= 0) return emptySet()
        val slice = yinAccum.copyOf(yinN)
        val poly = PolyYinPitch.midisFromPcm16(slice, sr)
        if (poly.isNotEmpty()) return poly
        val m = YinPitch.midiFromPcm16(slice, sr)
        return if (m != null) setOf(m) else emptySet()
    }

    private fun snapshotRing(ring: FloatArray, write: Int, fill: Int): FloatArray {
        val n = fill.coerceAtMost(ring.size)
        val out = FloatArray(n)
        val start = if (fill < ring.size) 0 else write
        for (i in 0 until n) {
            out[i] = ring[(start + i) % ring.size]
        }
        return out
    }

    /** Most recent [n] samples from the ring (for onset HF energy). */
    private fun snapshotLast(ring: FloatArray, write: Int, fill: Int, n: Int): FloatArray {
        val take = minOf(n, fill, ring.size)
        if (take <= 0) return FloatArray(0)
        val out = FloatArray(take)
        val start = if (fill < ring.size) {
            fill - take
        } else {
            (write - take + ring.size) % ring.size
        }
        for (i in 0 until take) {
            out[i] = ring[(start + i) % ring.size]
        }
        return out
    }

    private fun rms(samples: FloatArray): Float {
        if (samples.isEmpty()) return 0f
        var sum = 0.0
        for (s in samples) sum += s * s
        return kotlin.math.sqrt(sum / samples.size).toFloat()
    }

    companion object {
        private const val TAG = "PianoFlow/Pitch"
        private const val RMS_GATE = 0.005f
    }
}

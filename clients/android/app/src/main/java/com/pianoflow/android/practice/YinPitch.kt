package com.pianoflow.android.practice

import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.log2
import kotlin.math.roundToInt

/** Minimal YIN-style f0 → MIDI for follow mode. */
object YinPitch {
    fun midiFromPcm16(samples: ShortArray, sampleRate: Int, threshold: Float = 0.12f): Int? {
        if (samples.size < 512) return null
        val n = samples.size.coerceAtMost(2048)
        val x = FloatArray(n) { samples[it] / 32768f }
        var rms = 0.0
        for (v in x) rms += v * v
        rms = kotlin.math.sqrt(rms / n)
        if (rms < 0.01) return null

        val tauMax = (sampleRate / 60).coerceAtMost(n / 2)
        val tauMin = (sampleRate / 1000).coerceAtLeast(2)
        val d = FloatArray(tauMax + 1)
        for (tau in tauMin..tauMax) {
            var sum = 0f
            val limit = n - tau
            for (i in 0 until limit) {
                val diff = x[i] - x[i + tau]
                sum += diff * diff
            }
            d[tau] = sum
        }
        val cmnd = FloatArray(tauMax + 1)
        cmnd[0] = 1f
        var running = 0f
        for (tau in 1..tauMax) {
            running += d[tau]
            cmnd[tau] = if (running > 0) d[tau] * tau / running else 1f
        }
        var bestTau = -1
        for (tau in tauMin..tauMax) {
            if (cmnd[tau] < threshold) {
                while (tau + 1 <= tauMax && cmnd[tau + 1] < cmnd[tau]) {
                    // climb to local min — simplified: break at first valley start
                    break
                }
                var t = tau
                while (t + 1 <= tauMax && cmnd[t + 1] < cmnd[t]) t++
                bestTau = t
                break
            }
        }
        if (bestTau <= 0) {
            var minV = Float.MAX_VALUE
            for (tau in tauMin..tauMax) {
                if (cmnd[tau] < minV) {
                    minV = cmnd[tau]
                    bestTau = tau
                }
            }
            if (minV > 0.45f) return null
        }
        val hz = sampleRate.toDouble() / bestTau
        if (hz < 60 || hz > 2000) return null
        val midi = (69 + 12 * log2(hz / 440.0)).roundToInt()
        return midi.coerceIn(21, 108)
    }
}

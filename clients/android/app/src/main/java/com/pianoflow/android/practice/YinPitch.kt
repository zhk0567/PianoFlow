package com.pianoflow.android.practice

import kotlin.math.log2
import kotlin.math.roundToInt

/** Minimal YIN-style f0 → MIDI for follow mode (A0–C8). */
object YinPitch {
    /** A0 — was 60 Hz, which rejected deep bass (C2 ≈ 65 Hz barely passed). */
    const val minHz = 27.5
    const val maxHz = 4200.0

    fun midiFromPcm16(samples: ShortArray, sampleRate: Int, threshold: Float = 0.12f): Int? {
        if (samples.size < 512) return null
        // Need ≥~2 periods of A0 (~73 ms @ 22.05 kHz → ~1600 samples).
        val n = samples.size.coerceAtMost(8192)
        val x = FloatArray(n) { samples[it] / 32768f }
        var rms = 0.0
        for (v in x) rms += v * v
        rms = kotlin.math.sqrt(rms / n)
        if (rms < 0.008) return null

        val tauMax = (sampleRate / minHz).toInt().coerceAtMost(n / 2)
        val tauMin = (sampleRate / maxHz).toInt().coerceAtLeast(2)
        if (tauMax <= tauMin + 1) return null

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

        // Octave correct: piano bass H2 often wins first trough.
        val doubleTau = bestTau * 2
        if (doubleTau <= tauMax) {
            val at = cmnd[bestTau]
            val at2 = cmnd[doubleTau]
            if (at2 <= at * 1.12f && at2 < 0.26f) {
                bestTau = doubleTau
            }
        }

        val hz = sampleRate.toDouble() / bestTau
        if (hz < minHz || hz > maxHz) return null
        val midi = (69 + 12 * log2(hz / 440.0)).roundToInt()
        return midi.coerceIn(21, 108)
    }
}

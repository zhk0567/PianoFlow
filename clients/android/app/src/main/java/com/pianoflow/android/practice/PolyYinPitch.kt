package com.pianoflow.android.practice

/** Multi-peak YIN for polyphonic fallback (A0–C8). */
object PolyYinPitch {
    fun midisFromPcm16(samples: ShortArray, sampleRate: Int, threshold: Double = 0.14): Set<Int> {
        val n = minOf(samples.size, 8192)
        if (n < 1024) return emptySet()
        val x = DoubleArray(n)
        var rms = 0.0
        for (i in 0 until n) {
            val v = samples[i] / 32768.0
            x[i] = v
            rms += v * v
        }
        rms = kotlin.math.sqrt(rms / n)
        if (rms < 0.008) return emptySet()

        val tauMax = minOf((sampleRate / YinPitch.minHz).toInt(), n / 2)
        val tauMin = maxOf(2, (sampleRate / YinPitch.maxHz).toInt())
        if (tauMax <= tauMin + 1) return emptySet()

        val d = DoubleArray(tauMax + 1)
        for (tau in tauMin..tauMax) {
            var sum = 0.0
            val limit = n - tau
            for (i in 0 until limit) {
                val diff = x[i] - x[i + tau]
                sum += diff * diff
            }
            d[tau] = sum
        }
        val cmnd = DoubleArray(tauMax + 1)
        cmnd[0] = 1.0
        var running = 0.0
        for (tau in 1..tauMax) {
            running += d[tau]
            cmnd[tau] = if (running > 0) (d[tau] * tau) / running else 1.0
        }
        val peaks = mutableListOf<Pair<Int, Double>>()
        for (tau in (tauMin + 1) until tauMax) {
            if (cmnd[tau] < threshold && cmnd[tau] <= cmnd[tau - 1] && cmnd[tau] <= cmnd[tau + 1]) {
                peaks.add(tau to cmnd[tau])
            }
        }
        peaks.sortBy { it.second }
        val out = linkedSetOf<Int>()
        for ((tau, _) in peaks) {
            var t = tau
            val doubleTau = t * 2
            if (doubleTau <= tauMax) {
                val at = cmnd[t]
                val at2 = cmnd[doubleTau]
                if (at2 <= at * 1.12 && at2 < 0.26) t = doubleTau
            }
            val m = tauToMidi(t, sampleRate) ?: continue
            if (out.none { kotlin.math.abs(it - m) <= 1 }) out.add(m)
            if (out.size >= 4) break
        }
        if (out.isEmpty() && peaks.isNotEmpty()) {
            tauToMidi(peaks.first().first, sampleRate)?.let { out.add(it) }
        }
        return out
    }

    private fun tauToMidi(tau: Int, sampleRate: Int): Int? {
        if (tau <= 0) return null
        val hz = sampleRate.toDouble() / tau
        if (hz < YinPitch.minHz || hz > YinPitch.maxHz) return null
        val midi = kotlin.math.round(
            69 + 12 * kotlin.math.ln(hz / 440.0) / kotlin.math.ln(2.0),
        ).toInt()
        return midi.coerceIn(21, 108)
    }
}

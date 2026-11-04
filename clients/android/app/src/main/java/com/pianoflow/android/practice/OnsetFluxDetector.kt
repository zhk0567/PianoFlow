package com.pianoflow.android.practice

import kotlin.math.max
import kotlin.math.sqrt

/** Port of lib/features/practice/onset_flux.dart */
class OnsetFluxDetector(
    private val fluxThresh: Float = 0.028f,
    private val ratioThresh: Float = 1.55f,
    private val minRms: Float = 0.008f,
    private val cooldownHops: Int = 3,
) {
    private var prevHf = 0f
    private var cooldown = 0
    var lastFlux = 0f
        private set

    fun reset() {
        prevHf = 0f
        cooldown = 0
        lastFlux = 0f
    }

    fun push(samples: FloatArray): Boolean {
        if (samples.size < 64) {
            lastFlux = 0f
            return false
        }
        if (cooldown > 0) {
            cooldown--
            val hf = highFreqEnergy(samples)
            prevHf = prevHf * 0.65f + hf * 0.35f
            lastFlux = 0f
            return false
        }
        val hf = highFreqEnergy(samples)
        val rms = rms(samples)
        val flux = max(0f, hf - prevHf)
        lastFlux = flux
        val rising = if (prevHf <= 1e-6f) hf >= fluxThresh else hf >= prevHf * ratioThresh
        val onset = rms >= minRms && flux >= fluxThresh && rising
        prevHf = prevHf * 0.55f + hf * 0.45f
        if (onset) cooldown = cooldownHops.coerceAtLeast(1)
        return onset
    }

    companion object {
        fun highFreqEnergy(samples: FloatArray): Float {
            if (samples.size < 2) return 0f
            var sum = 0.0
            for (i in 1 until samples.size) {
                val d = (samples[i] - samples[i - 1]).toDouble()
                sum += d * d
            }
            return sqrt(sum / (samples.size - 1)).toFloat()
        }

        fun rms(samples: FloatArray): Float {
            if (samples.isEmpty()) return 0f
            var sum = 0.0
            for (s in samples) sum += s * s
            return sqrt(sum / samples.size).toFloat()
        }
    }
}

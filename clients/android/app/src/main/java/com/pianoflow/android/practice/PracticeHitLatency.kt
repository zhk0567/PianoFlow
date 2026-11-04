package com.pianoflow.android.practice

import android.util.Log
import kotlin.math.roundToInt

/**
 * Follow-mode lab metrics — schema aligned with Dart PracticeHitLatency.
 */
object PracticeHitLatency {
    const val MAX_SAMPLES = 256

    private val samplesAll = ArrayList<Int>()
    private val samplesGuideOn = ArrayList<Int>()
    private val samplesGuideOff = ArrayList<Int>()

    var hits = 0
        private set
    var hitsGuideOn = 0
        private set
    var hitsGuideOff = 0
        private set
    var misses = 0
        private set
    var latchBlocks = 0
        private set
    var softMatches = 0
        private set
    var leaks = 0
        private set
    var frameHitsGuideOn = 0
        private set
    var onsetReleases = 0
        private set
    var cueBleeds = 0
        private set

    fun reset() {
        samplesAll.clear()
        samplesGuideOn.clear()
        samplesGuideOff.clear()
        hits = 0
        hitsGuideOn = 0
        hitsGuideOff = 0
        misses = 0
        latchBlocks = 0
        softMatches = 0
        leaks = 0
        frameHitsGuideOn = 0
        onsetReleases = 0
        cueBleeds = 0
    }

    fun record(elapsedMs: Int, guideOn: Boolean = false, path: String = "noteOn"): Int {
        val v = elapsedMs.coerceAtLeast(0)
        push(samplesAll, v)
        if (guideOn) {
            push(samplesGuideOn, v)
            hitsGuideOn++
            if (path == "frame") frameHitsGuideOn++
        } else {
            push(samplesGuideOff, v)
            hitsGuideOff++
        }
        hits++
        return v
    }

    fun noteMiss() { misses++ }
    fun noteLatchBlock() { latchBlocks++ }
    fun noteSoftMatch() { softMatches++ }
    fun noteLeak() { leaks++ }
    fun noteOnsetRelease() { onsetReleases++ }
    fun noteCueBleed() { cueBleeds++ }

    fun p50Ms(): Int? = percentile(samplesAll, 50)
    fun p95Ms(): Int? = percentile(samplesAll, 95)

    fun snapshotLine(): String {
        val p50 = p50Ms()
        val p95 = p95Ms()
        val buf = StringBuilder("metrics")
        buf.append(" hits=").append(hits)
        buf.append(" miss=").append(misses)
        if (hits + misses > 0) {
            val rate = misses * 100.0 / (hits + misses)
            buf.append(" missRate=").append("%.1f".format(rate)).append("%")
        }
        buf.append(" latchBlock=").append(latchBlocks)
        buf.append(" softMatch=").append(softMatches)
        buf.append(" leak=").append(leaks)
        buf.append(" onsetRel=").append(onsetReleases)
        buf.append(" cueBleed=").append(cueBleeds)
        buf.append(" frameGuide=").append(frameHitsGuideOn)
        if (p50 != null) buf.append(" p50=").append(p50).append("ms")
        if (p95 != null) buf.append(" p95=").append(p95).append("ms")
        buf.append(" n=").append(samplesAll.size)
        return buf.toString()
    }

    fun logIfPractice() {
        Log.i("PianoFlow/Practice", snapshotLine())
    }

    private fun push(list: MutableList<Int>, v: Int) {
        list.add(v)
        while (list.size > MAX_SAMPLES) list.removeAt(0)
    }

    private fun percentile(list: List<Int>, p: Int): Int? {
        if (list.isEmpty()) return null
        val sorted = list.sorted()
        val rank = (p.coerceIn(0, 100) / 100.0) * (sorted.size - 1)
        val lo = rank.toInt()
        val hi = kotlin.math.ceil(rank).toInt()
        if (lo == hi) return sorted[lo]
        val t = rank - lo
        return (sorted[lo] * (1 - t) + sorted[hi] * t).roundToInt()
    }
}

package com.pianoflow.android.practice

/**
 * Soft-cue bleed filter — port of cue_bleed_guard.dart.
 * Does not retune echoSuppressGuideMs.
 */
class CueBleedGuard(
    private val softTailMs: Long = 180L,
    private val hardSuppressMs: Long = PracticeConsts.echoSuppressGuideMs,
    private val reedgeGraceMs: Long = 50L,
) {
    private var cued: Set<Int> = emptySet()
    private var cueAtMs: Long = 0L

    fun arm(midis: Collection<Int>, atMs: Long = System.currentTimeMillis()) {
        cued = midis.toSet()
        cueAtMs = atMs
    }

    fun clear() {
        cued = emptySet()
        cueAtMs = 0L
    }

    private fun nearCue(midi: Int): Boolean =
        cued.any { PitchMatch.isNear(it, midi) || PitchMatch.isOctaveRelative(it, midi) }

    private fun onlyCueNeighborhood(heard: Set<Int>): Boolean {
        if (heard.isEmpty()) return true
        return heard.all { nearCue(it) }
    }

    fun isBleed(
        midi: Int,
        hasOnset: Boolean,
        heardAll: Set<Int>,
        nowMs: Long = System.currentTimeMillis(),
    ): Boolean {
        if (cued.isEmpty() || cueAtMs == 0L) return false
        if (!nearCue(midi)) return false
        if (hasOnset) return false

        val hardEnd = cueAtMs + hardSuppressMs
        val softEnd = hardEnd + softTailMs
        if (nowMs < hardEnd) return true
        if (nowMs < softEnd) {
            if (nowMs - hardEnd < reedgeGraceMs) return false
            return onlyCueNeighborhood(heardAll)
        }
        return false
    }
}

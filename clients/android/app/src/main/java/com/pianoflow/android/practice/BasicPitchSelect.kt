package com.pianoflow.android.practice

/**
 * Basic Pitch note selection — port of lib/features/practice/basic_pitch.dart
 * (selectNotes + bass octave recovery + neighbor bleed).
 */
object BasicPitchSelect {
    const val MIDI_OFFSET = 21
    const val N_BINS = 88
    const val MIN_MIDI = 21
    const val MAX_MIDI = 108
    const val BASS_MIDI_CEILING = 48
    const val BASS_FUND_FLOOR = 0.18

    private val PARTIALS = setOf(12, 19, 24, 28, 31, 36)

    data class Cand(val midi: Int, val score: Double)

    fun selectNotes(
        scores: DoubleArray,
        frameThresh: Double = 0.42,
        relativeThresh: Double = 0.60,
        priorMidis: Set<Int>? = null,
        priorBoost: Double = 1.35,
    ): Set<Int> {
        val work = scores.copyOf()
        if (priorMidis != null && priorMidis.isNotEmpty() && priorBoost > 1.0) {
            for (m in priorMidis) {
                val b = m - MIDI_OFFSET
                if (b !in work.indices) continue
                work[b] = (work[b] * priorBoost).coerceIn(0.0, 1.0)
            }
        }
        var peak = 0.0
        for (s in work) if (s > peak) peak = s
        if (peak < frameThresh * 0.85) return emptySet()

        val floor = maxOf(frameThresh, peak * relativeThresh)
        val bassFloor = maxOf(frameThresh * 0.55, peak * relativeThresh * 0.65)
        val candidates = ArrayList<Cand>()
        val n = minOf(N_BINS, work.size)
        for (b in 0 until n) {
            val s = work[b]
            val midi = MIDI_OFFSET + b
            if (midi < MIN_MIDI || midi > MAX_MIDI) continue
            val binFloor = if (midi <= BASS_MIDI_CEILING) bassFloor else floor
            if (s < binFloor) continue
            candidates.add(Cand(midi, s))
        }
        if (candidates.isEmpty()) return emptySet()
        candidates.sortByDescending { it.score }

        val kept = ArrayList<Cand>()
        for (c in candidates) {
            if (isPartialGhost(c, kept)) continue
            if (isNeighborBleed(c, kept)) continue
            kept.add(c)
            if (kept.size >= 6) break
        }

        val midis = kept.map { it.midi }.toMutableSet()
        for (m in midis.sorted()) {
            if (midis.contains(m + 12)) {
                val low = kept.first { it.midi == m }
                val high = kept.first { it.midi == m + 12 }
                if (high.score < frameThresh && high.score <= low.score * 1.25) {
                    midis.remove(m + 12)
                }
            }
        }
        return recoverBassFundamentals(work, midis, frameThresh)
    }

    private fun recoverBassFundamentals(
        scores: DoubleArray,
        selected: Set<Int>,
        frameThresh: Double,
    ): Set<Int> {
        if (selected.isEmpty()) return selected
        val out = LinkedHashSet<Int>()
        for (m in selected) {
            val low = m - 12
            if (m <= BASS_MIDI_CEILING ||
                m > BASS_MIDI_CEILING + 12 ||
                low < MIN_MIDI ||
                low > BASS_MIDI_CEILING
            ) {
                out.add(m)
                continue
            }
            val ls = scoreAt(scores, low)
            val hs = scoreAt(scores, m)
            if (ls < BASS_FUND_FLOOR || hs > ls * 2.8) {
                out.add(m)
                continue
            }
            out.add(low)
            val bothReal = hs >= frameThresh &&
                ls >= frameThresh * 0.85 &&
                hs >= ls * 0.8
            if (bothReal) out.add(m)
        }
        return out
    }

    private fun scoreAt(scores: DoubleArray, midi: Int): Double {
        val b = midi - MIDI_OFFSET
        if (b < 0 || b >= scores.size) return 0.0
        return scores[b]
    }

    private fun isPartialGhost(c: Cand, kept: List<Cand>): Boolean {
        for (k in kept) {
            val interval = c.midi - k.midi
            if (interval <= 0) continue
            if (interval !in PARTIALS) continue
            if (interval == 12 &&
                k.midi <= BASS_MIDI_CEILING &&
                c.score >= 0.42 &&
                k.score >= 0.42 * 0.85
            ) {
                continue
            }
            val margin = if (k.midi <= BASS_MIDI_CEILING) 1.15 else 1.35
            if (c.score < k.score * margin) return true
        }
        return false
    }

    private fun isNeighborBleed(c: Cand, kept: List<Cand>): Boolean {
        for (k in kept) {
            if (kotlin.math.abs(c.midi - k.midi) != 1) continue
            if (c.score < k.score * 0.88) return true
        }
        return false
    }

    fun tailMeanScores(frames: Array<DoubleArray>, tail: Int = 4): DoubleArray {
        if (frames.isEmpty()) return DoubleArray(N_BINS)
        val n = minOf(tail, frames.size)
        val start = frames.size - n
        val scores = DoubleArray(N_BINS)
        for (t in start until frames.size) {
            val row = frames[t]
            for (b in 0 until minOf(N_BINS, row.size)) {
                scores[b] += row[b]
            }
        }
        for (b in 0 until N_BINS) scores[b] /= n.toDouble()
        return scores
    }
}

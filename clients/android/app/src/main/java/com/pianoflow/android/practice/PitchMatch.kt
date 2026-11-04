package com.pianoflow.android.practice

import kotlin.math.abs

/**
 * Port of lib/features/practice/practice_pitch_match.dart
 * (score-conditioned: soft ±1 only for monophonic waits).
 */
object PitchMatch {
    const val SEMITONE_TOLERANCE = 1
    const val SOFT_SEMITONE_MAX_WAITING = 1
    const val BASS_OCTAVE_CEILING = 48

    fun isNear(expected: Int, heard: Int): Boolean =
        abs(expected - heard) <= SEMITONE_TOLERANCE

    fun isOctaveRelative(expected: Int, heard: Int): Boolean =
        abs(expected - heard) == 12

    fun softSemitoneAllowed(waitingFor: Set<Int>): Boolean =
        waitingFor.size <= SOFT_SEMITONE_MAX_WAITING

    fun isHeardNear(
        expected: Int,
        heard: Set<Int>,
        allowSoftSemitone: Boolean = true,
    ): Boolean {
        for (h in heard) {
            if (h == expected || isOctaveRelative(expected, h)) return true
            if (allowSoftSemitone && isNear(expected, h)) return true
        }
        return false
    }

    fun conditionHeard(heard: Set<Int>, waitingFor: Set<Int>): Set<Int> {
        if (heard.isEmpty() || waitingFor.isEmpty()) return heard
        val soft = softSemitoneAllowed(waitingFor)
        val out = LinkedHashSet<Int>()
        for (h in heard) {
            for (e in waitingFor) {
                if (h == e || isOctaveRelative(e, h)) {
                    out.add(h)
                    break
                }
                if (soft && isNear(e, h)) {
                    out.add(h)
                    break
                }
            }
        }
        return out
    }

    fun priorBins(waitingFor: Set<Int>): Set<Int> {
        if (waitingFor.isEmpty()) return emptySet()
        val out = LinkedHashSet<Int>()
        for (m in waitingFor) {
            for (x in listOf(m - 12, m - 1, m, m + 1, m + 12)) {
                if (x in 21..108) out.add(x)
            }
        }
        return out
    }

    fun isForgivableWrongPitch(heard: Int, waitingFor: Set<Int>): Boolean {
        if (waitingFor.isEmpty()) return false
        val soft = softSemitoneAllowed(waitingFor)
        for (e in waitingFor) {
            if (isOctaveRelative(e, heard)) return true
            if (soft && isNear(e, heard)) return true
        }
        return false
    }

    fun matchWaiting(heard: Set<Int>, waitingFor: Set<Int>): Set<Int> {
        if (heard.isEmpty() || waitingFor.isEmpty()) return emptySet()
        val conditioned = conditionHeard(heard, waitingFor)
        if (conditioned.isEmpty()) return emptySet()
        val remaining = waitingFor.toMutableSet()
        val hits = LinkedHashSet<Int>()
        val usedHeard = HashSet<Int>()
        val soft = softSemitoneAllowed(waitingFor)

        for (h in conditioned) {
            if (remaining.remove(h)) {
                hits.add(h)
                usedHeard.add(h)
            }
        }
        if (soft) {
            for (h in conditioned) {
                if (h in usedHeard) continue
                var best: Int? = null
                var bestDist = SEMITONE_TOLERANCE + 1
                for (e in remaining) {
                    val d = abs(e - h)
                    if (d == 0 || d > SEMITONE_TOLERANCE) continue
                    if (d < bestDist || (d == bestDist && (best == null || e < best))) {
                        best = e
                        bestDist = d
                    }
                }
                if (best != null) {
                    remaining.remove(best)
                    hits.add(best)
                    usedHeard.add(h)
                }
            }
        }
        for (h in conditioned) {
            if (h in usedHeard) continue
            if (h in waitingFor) continue
            var best: Int? = null
            for (e in remaining) {
                if (!isOctaveRelative(e, h)) continue
                if (best == null || e < best) best = e
            }
            if (best == null) continue
            remaining.remove(best)
            hits.add(best)
            usedHeard.add(h)
        }
        return hits
    }

    fun matchNoteOn(midi: Int, waitingFor: Set<Int>): Int? {
        if (waitingFor.isEmpty()) return null
        if (midi in waitingFor) return midi
        val hits = matchWaiting(setOf(midi), waitingFor)
        return hits.firstOrNull()
    }
}

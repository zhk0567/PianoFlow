package com.pianoflow.android.practice

/** Port of lib/features/practice/guide_retrigger_gate.dart */
class GuideRetriggerGate(private val quietFramesNeeded: Int = 2) {
    private val awaitingGap = HashSet<Int>()
    private val gapSeen = HashSet<Int>()
    private val quietFrames = HashMap<Int, Int>()

    fun arm(midis: Collection<Int>) {
        for (m in midis) {
            awaitingGap.add(m)
            gapSeen.remove(m)
            quietFrames[m] = 0
        }
    }

    fun disarm(midis: Collection<Int>) {
        for (m in midis) {
            awaitingGap.remove(m)
            gapSeen.remove(m)
            quietFrames.remove(m)
        }
    }

    fun clear() {
        awaitingGap.clear()
        gapSeen.clear()
        quietFrames.clear()
    }

    fun blocks(midi: Int): Boolean {
        for (m in awaitingGap) {
            if (m in gapSeen) continue
            if (PitchMatch.isNear(m, midi)) return true
            if (PitchMatch.isOctaveRelative(m, midi)) return true
        }
        return false
    }

    fun acceptHits(
        heard: Set<Int>,
        waitingFor: Set<Int>,
        stillSuppressed: Set<Int> = emptySet(),
    ): Set<Int> {
        val needed = quietFramesNeeded.coerceAtLeast(1)
        for (m in awaitingGap.toList()) {
            val suppressedNear = stillSuppressed.any { PitchMatch.isNear(m, it) }
            if (suppressedNear) {
                quietFrames[m] = 0
                continue
            }
            if (!PitchMatch.isHeardNear(m, heard)) {
                val n = (quietFrames[m] ?: 0) + 1
                quietFrames[m] = n
                if (n >= needed) gapSeen.add(m)
            } else if (m !in gapSeen) {
                quietFrames[m] = 0
            }
        }
        if (awaitingGap.isEmpty()) return emptySet()
        val matched = PitchMatch.matchWaiting(heard, waitingFor)
        val hits = LinkedHashSet<Int>()
        for (m in matched) {
            if (m !in awaitingGap) continue
            if (m !in gapSeen) continue
            awaitingGap.remove(m)
            gapSeen.remove(m)
            quietFrames.remove(m)
            hits.add(m)
        }
        return hits
    }
}

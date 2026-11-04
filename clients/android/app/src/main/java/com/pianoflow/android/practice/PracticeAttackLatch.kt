package com.pianoflow.android.practice

/** Port of lib/features/practice/practice_attack_latch.dart */
class PracticeAttackLatch(
    private val releaseFrames: Int = 2,
    private val postHitReleaseFrames: Int = 5,
    private val onsetRefractoryFrames: Int = 6,
) {
    private val spent = HashSet<Int>()
    private val quietFrames = HashMap<Int, Int>()
    private val quietNeeded = HashMap<Int, Int>()
    private val onsetRefractory = HashMap<Int, Int>()

    val spentCount: Int get() = spent.size

    fun clear() {
        spent.clear()
        quietFrames.clear()
        quietNeeded.clear()
        onsetRefractory.clear()
    }

    fun markConsumed(waitingMidi: Int, heardMidi: Int? = null) {
        arm(waitingMidi, postHit = true)
        if (heardMidi != null) arm(heardMidi, postHit = true)
    }

    fun blocks(midi: Int): Boolean {
        for (s in spent) {
            if (PitchMatch.isNear(s, midi)) return true
            if (PitchMatch.isOctaveRelative(s, midi)) return true
        }
        return false
    }

    fun onHeard(heard: Set<Int>) {
        tickOnsetRefractory()
        if (spent.isEmpty()) return
        for (m in spent.toList()) {
            if (PitchMatch.isHeardNear(m, heard)) {
                quietFrames[m] = 0
                continue
            }
            val needed = quietNeeded[m] ?: releaseFrames.coerceAtLeast(1)
            val n = (quietFrames[m] ?: 0) + 1
            if (n >= needed) {
                clearRoot(m)
            } else {
                quietFrames[m] = n
            }
        }
    }

    /**
     * Strong re-attack while pitch still heard — clear spent for [heard].
     * Blocked during post-hit onset refractory (anti one-strike multi-advance).
     */
    fun releaseOnOnset(heard: Set<Int>) {
        if (spent.isEmpty() || heard.isEmpty()) return
        for (m in spent.toList()) {
            if (!PitchMatch.isHeardNear(m, heard)) continue
            if (onsetRefractoryActive(m)) continue
            clearRoot(m)
        }
    }

    /**
     * Store the consumed pitch only. [blocks] applies ±1 and exact ±12.
     * Arming the octave bin itself made isNear() reject a chord tone 11
     * semitones away (C4 after B4).
     */
    private fun arm(midi: Int, postHit: Boolean) {
        if (midi < 21 || midi > 108) return
        spent.add(midi)
        quietFrames[midi] = 0
        if (postHit) {
            quietNeeded[midi] = postHitReleaseFrames.coerceAtLeast(1)
            onsetRefractory[midi] = onsetRefractoryFrames.coerceAtLeast(0)
        }
    }

    private fun clearRoot(midi: Int) {
        spent.remove(midi)
        quietFrames.remove(midi)
        quietNeeded.remove(midi)
        onsetRefractory.remove(midi)
    }

    private fun tickOnsetRefractory() {
        if (onsetRefractory.isEmpty()) return
        for (m in onsetRefractory.keys.toList()) {
            val n = (onsetRefractory[m] ?: 0) - 1
            if (n <= 0) onsetRefractory.remove(m)
            else onsetRefractory[m] = n
        }
    }

    private fun onsetRefractoryActive(midi: Int): Boolean {
        for ((root, left) in onsetRefractory) {
            if (left <= 0) continue
            if (PitchMatch.isNear(root, midi)) return true
            if (PitchMatch.isOctaveRelative(root, midi)) return true
        }
        return false
    }
}

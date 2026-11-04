package com.pianoflow.android.practice

/**
 * Lock / release hysteresis → noteOn edges (port of PitchService emitted logic).
 */
class PitchEdgeTracker(
    private val lockFrames: Int = 1,
    private val releaseFrames: Int = 1,
) {
    private val lockCount = HashMap<Int, Int>()
    private val releaseCount = HashMap<Int, Int>()
    private val locked = HashSet<Int>()
    private val emitted = HashSet<Int>()

    fun clear() {
        lockCount.clear()
        releaseCount.clear()
        locked.clear()
        emitted.clear()
    }

    /** Clear emitted so held tones can re-fire after guide suppress. */
    fun clearEmitted(midis: Collection<Int>? = null) {
        if (midis == null) {
            emitted.clear()
            return
        }
        emitted.removeAll(midis.toSet())
    }

    /**
     * Update from current active MIDI set.
     * @return newly locked note-ons this frame
     */
    fun update(active: Set<Int>): Set<Int> {
        val noteOns = LinkedHashSet<Int>()
        for (m in active) {
            releaseCount.remove(m)
            val n = (lockCount[m] ?: 0) + 1
            lockCount[m] = n
            if (n >= lockFrames && !locked.contains(m)) {
                locked.add(m)
                if (!emitted.contains(m)) {
                    emitted.add(m)
                    noteOns.add(m)
                }
            }
        }
        val gone = locked.filter { it !in active }
        for (m in gone) {
            lockCount.remove(m)
            val n = (releaseCount[m] ?: 0) + 1
            if (n >= releaseFrames) {
                releaseCount.remove(m)
                locked.remove(m)
                emitted.remove(m)
            } else {
                releaseCount[m] = n
            }
        }
        // Drop lock counters for pitches no longer active and not locked.
        val staleLocks = lockCount.keys.filter { it !in active && it !in locked }
        for (m in staleLocks) lockCount.remove(m)
        return noteOns
    }

    fun lockedMidis(): Set<Int> = locked.toSet()
}

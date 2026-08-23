package com.pianoflow.android.practice

/** Port of Flutter PracticeWaitLogic / judge constants (Windows parity). */
object PracticeConsts {
    const val waitEarlyHitBeats = 0.45
    const val waitFreezeSlackBeats = 0.02
    const val waitChordClusterBeats = 0.02
    const val waitAdvanceEpsilonBeats = 0.04
    const val judgePerfectBeats = 0.08
    const val echoSuppressGuideMs = 250L
    const val playbackLeadInBeats = 1.0
    const val speedMin = 0.4f
    const val speedMax = 2.0f
}

object WaitLogic {
    fun nextTarget(notes: List<ScoreNote>, pos: Double): ScoreNote? {
        for (n in notes) {
            if (n.start + 0.001 >= pos - 0.001) return n
        }
        return null
    }

    fun chordMidis(notes: List<ScoreNote>, target: ScoreNote): Set<Int> {
        val c = PracticeConsts.waitChordClusterBeats
        return notes.filter { kotlin.math.abs(it.start - target.start) < c }
            .map { it.midi }
            .toSet()
    }

    fun expectedAt(notes: List<ScoreNote>, pos: Double): Set<Int> {
        val target = nextTarget(notes, pos) ?: return emptySet()
        if (target.start > pos + PracticeConsts.waitEarlyHitBeats) return emptySet()
        return chordMidis(notes, target)
    }

    fun shouldFreeze(pos: Double, chordStart: Double): Boolean =
        pos >= chordStart - PracticeConsts.waitFreezeSlackBeats

    fun nudgePast(notes: List<ScoreNote>, pos: Double): Double {
        val c = PracticeConsts.waitChordClusterBeats
        val atPos = notes.filter { kotlin.math.abs(it.start - pos) < c }
        if (atPos.isNotEmpty()) {
            return atPos.first().start + PracticeConsts.waitAdvanceEpsilonBeats
        }
        val target = nextTarget(notes, pos)
        if (target != null && target.start <= pos + PracticeConsts.waitEarlyHitBeats) {
            return target.start + PracticeConsts.waitAdvanceEpsilonBeats
        }
        return pos + PracticeConsts.waitAdvanceEpsilonBeats
    }

    fun chordStart(notes: List<ScoreNote>, expected: Set<Int>, pos: Double): Double? {
        if (expected.isEmpty()) return null
        val target = nextTarget(notes, pos) ?: return null
        return target.start
    }
}

enum class HitGrade { Perfect, Good }

object JudgeLogic {
    fun grade(deltaBeats: Double): HitGrade {
        val a = kotlin.math.abs(deltaBeats)
        return if (a <= PracticeConsts.judgePerfectBeats) HitGrade.Perfect else HitGrade.Good
    }
}

object WeakLoopLogic {
    fun suggest(missBeats: List<Double>, duration: Double): Pair<Double, Double>? {
        if (missBeats.isEmpty() || duration <= 0.5) return null
        val sorted = missBeats.sorted()
        var bestCount = 0
        var bestLo = sorted.first()
        var bestHi = sorted.first()
        var j = 0
        for (i in sorted.indices) {
            while (j < sorted.size && sorted[j] - sorted[i] <= 8.0 + 1e-9) j++
            val count = j - i
            if (count > bestCount) {
                bestCount = count
                bestLo = sorted[i]
                bestHi = sorted[j - 1]
            }
        }
        var start = (bestLo - 1.0).coerceIn(0.0, duration)
        var end = (bestHi + 1.0).coerceIn(0.0, duration)
        if (end - start < 1.0) {
            end = (start + 2.0).coerceIn(0.0, duration)
            if (end - start < 1.0) start = (end - 2.0).coerceIn(0.0, duration)
        }
        if (end <= start + 0.5) return null
        return start to end
    }

    fun labelZh(start: Double, end: Double): String =
        "练薄弱段（约 ${start.toInt()}–${end.toInt()} 拍）"
}

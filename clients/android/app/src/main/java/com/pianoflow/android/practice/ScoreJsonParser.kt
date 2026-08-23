package com.pianoflow.android.practice

import org.json.JSONObject

enum class Hand { Left, Right, Both }

data class ScoreNote(
    val midi: Int,
    val start: Double,
    val duration: Double,
    val hand: Hand,
) {
    val onsetBeats: Double get() = start
    val durationBeats: Double get() = duration
}

object ScoreJsonParser {
    fun parse(jsonText: String): Pair<Double, List<ScoreNote>> {
        val root = JSONObject(jsonText)
        val bpm = root.optDouble("bpm", 72.0)
        val arr = root.getJSONArray("notes")
        val notes = ArrayList<ScoreNote>(arr.length())
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val hand = when (o.optString("hand", "right")) {
                "left" -> Hand.Left
                "right" -> Hand.Right
                else -> Hand.Right
            }
            notes.add(
                ScoreNote(
                    midi = o.getInt("midi"),
                    start = o.getDouble("start"),
                    duration = o.getDouble("duration").coerceAtLeast(0.05),
                    hand = hand,
                ),
            )
        }
        notes.sortBy { it.start }
        return bpm to notes
    }

    fun filter(notes: List<ScoreNote>, hand: Hand): List<ScoreNote> =
        when (hand) {
            Hand.Both -> notes
            Hand.Left -> notes.filter { it.hand == Hand.Left }
            Hand.Right -> notes.filter { it.hand == Hand.Right }
        }
}

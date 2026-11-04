package com.pianoflow.android.practice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BasicPitchSelectTest {
    @Test
    fun peakBelowGateReturnsEmpty() {
        val scores = DoubleArray(88) { 0.1 }
        assertTrue(BasicPitchSelect.selectNotes(scores).isEmpty())
    }

    @Test
    fun strongestBinSelected() {
        val scores = DoubleArray(88) { 0.0 }
        // MIDI 60 = C4 → bin 60-21 = 39
        scores[39] = 0.9
        val midis = BasicPitchSelect.selectNotes(scores)
        assertEquals(setOf(60), midis)
    }

    @Test
    fun neighborBleedDropped() {
        val scores = DoubleArray(88) { 0.0 }
        scores[39] = 0.9 // 60
        scores[40] = 0.5 // 61 — weak neighbor
        val midis = BasicPitchSelect.selectNotes(scores)
        assertEquals(setOf(60), midis)
    }
}

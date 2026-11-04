# -*- coding: utf-8 -*-
"""Pure tests for replay_follow_bench (no ONNX)."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import replay_follow_bench as bench  # noqa: E402


class SelectNotesTest(unittest.TestCase):
    def test_neighbor_bleed_dropped(self) -> None:
        scores = np.zeros(88, dtype=np.float64)
        scores[60 - 21] = 0.80
        scores[61 - 21] = 0.50  # 0.50 < 0.80 * 0.88
        got = bench.select_notes(scores, prior_midis=None, prior_boost=1.0)
        self.assertIn(60, got)
        self.assertNotIn(61, got)

    def test_chord_keeps_four_strong(self) -> None:
        scores = np.zeros(88, dtype=np.float64)
        for m in (60, 64, 67, 71):
            scores[m - 21] = 0.7
        got = bench.select_notes(scores, prior_midis=None, prior_boost=1.0)
        self.assertTrue({60, 64, 67, 71} <= got)


class MatchTest(unittest.TestCase):
    def test_chord_rejects_semitone(self) -> None:
        hits = bench.match_waiting({61, 65, 68, 73}, {60, 64, 67, 72})
        self.assertEqual(hits, set())

    def test_mono_allows_semitone(self) -> None:
        self.assertEqual(bench.match_note_on(61, {60}), 60)

    def test_exact_chord(self) -> None:
        hits = bench.match_waiting({60, 64, 67, 72}, {60, 64, 67, 72})
        self.assertEqual(hits, {60, 64, 67, 72})


class CueBleedTest(unittest.TestCase):
    def test_hard_window_blocks_without_onset(self) -> None:
        g = bench.CueBleed()
        g.arm({60}, 1.0)
        self.assertTrue(g.is_bleed(60, False, {60}, 1.10))

    def test_onset_passes(self) -> None:
        g = bench.CueBleed()
        g.arm({60}, 1.0)
        self.assertFalse(g.is_bleed(60, True, {60}, 1.10))

    def test_grace_then_soft_tail(self) -> None:
        g = bench.CueBleed()
        g.arm({60}, 1.0)
        hard_end = 1.0 + bench.ECHO_GUIDE_SEC
        self.assertFalse(g.is_bleed(60, False, {60}, hard_end + 0.02))
        self.assertTrue(g.is_bleed(60, False, {60}, hard_end + 0.08))


class LatchTest(unittest.TestCase):
    def test_quiet_releases(self) -> None:
        latch = bench.AttackLatch()
        latch.mark(60, 60)
        self.assertTrue(latch.blocks(60))
        latch.on_heard(set())
        self.assertTrue(latch.blocks(60))
        latch.on_heard(set())
        self.assertFalse(latch.blocks(60))

    def test_onset_releases_while_heard(self) -> None:
        latch = bench.AttackLatch()
        latch.mark(60, 60)
        self.assertTrue(latch.release_on_onset({60}))
        self.assertFalse(latch.blocks(60))

    def test_major_seventh_not_smeared(self) -> None:
        latch = bench.AttackLatch()
        latch.mark(71, 71)
        self.assertFalse(latch.blocks(60))
        self.assertTrue(latch.blocks(59))


if __name__ == "__main__":
    unittest.main()

# -*- coding: utf-8 -*-
"""Unit tests for Campaign F compare_amt_latency (no rtt required)."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import compare_amt_latency as cmp  # noqa: E402


class MatchOnsetsTest(unittest.TestCase):
    def test_perfect_match_f1(self) -> None:
        ref = [cmp.Onset(0.5, 60), cmp.Onset(1.0, 64)]
        est = [cmp.Onset(0.51, 60), cmp.Onset(1.02, 64)]
        f, lags = cmp.match_onsets(ref, est, tol_sec=0.05)
        self.assertAlmostEqual(f, 1.0)
        self.assertEqual(len(lags), 2)

    def test_wrong_pitch_zero(self) -> None:
        ref = [cmp.Onset(0.5, 60)]
        est = [cmp.Onset(0.5, 61)]
        f, lags = cmp.match_onsets(ref, est, tol_sec=0.05)
        self.assertEqual(f, 0.0)
        self.assertEqual(lags, [])

    def test_octave_optional(self) -> None:
        ref = [cmp.Onset(0.5, 60)]
        est = [cmp.Onset(0.5, 72)]
        f0, _ = cmp.match_onsets(ref, est, tol_sec=0.05, allow_octave=False)
        f1, _ = cmp.match_onsets(ref, est, tol_sec=0.05, allow_octave=True)
        self.assertEqual(f0, 0.0)
        self.assertAlmostEqual(f1, 1.0)

    def test_percentile(self) -> None:
        lags = [0.01, 0.02, 0.03, 0.04]
        p50 = cmp.percentile_ms(lags, 50)
        self.assertIsNotNone(p50)
        assert p50 is not None
        self.assertAlmostEqual(p50, 25.0, places=1)


class SynthAndReportTest(unittest.TestCase):
    def test_synthesize_nonempty(self) -> None:
        gt = cmp.default_self_check_gt()
        audio = cmp.synthesize_bursts(gt)
        self.assertGreater(len(audio), cmp.SR_BP)
        self.assertGreater(float(np_max_abs(audio)), 0.1)

    def test_build_report_shape(self) -> None:
        ref = [cmp.Onset(0.4, 60)]
        est = [cmp.Onset(0.45, 60)]
        r = cmp.build_report("toy", ref, est, infer_wall_ms=12.3, audio_sec=1.0)
        self.assertEqual(r.engine, "toy")
        self.assertEqual(r.n_ref, 1)
        self.assertEqual(r.n_est, 1)
        self.assertIsNotNone(r.note_on_f_100ms)
        self.assertGreater(r.note_on_f_100ms or 0, 0.9)


@unittest.skipUnless(
    (ROOT / "assets" / "models" / "basic_pitch.onnx").is_file(),
    "basic_pitch.onnx missing",
)
class BpSelfCheckSmoke(unittest.TestCase):
    def test_self_check_runs(self) -> None:
        ref = cmp.default_self_check_gt()
        audio = cmp.synthesize_bursts(ref)
        report = cmp.run_compare(audio_bp=audio, ref=ref, rtt_root=None)
        self.assertEqual(report["schema"], "pianoflow.amt_compare.v1")
        engines = report["engines"]
        self.assertEqual(engines[0]["engine"], "basic_pitch_stream")
        # Harmonic synth is not real piano — do not assert high F1.
        self.assertGreaterEqual(engines[0]["n_est"], 0)
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "report.json"
            out.write_text(json.dumps(report), encoding="utf-8")
            self.assertTrue(out.is_file())


def np_max_abs(audio) -> float:
    import numpy as np

    return float(np.max(np.abs(audio)))


if __name__ == "__main__":
    unittest.main()

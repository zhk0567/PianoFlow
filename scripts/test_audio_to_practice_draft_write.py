# -*- coding: utf-8 -*-
"""Smoke: audio draft events → userImport JSON (no ONNX)."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import audio_to_practice_draft as draft  # noqa: E402


class AudioDraftWriteTest(unittest.TestCase):
    def test_write_user_import_from_events(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            user_dir = Path(tmp)
            events = [
                (0.0, 0.4, 60),
                (0.4, 0.8, 64),
                (0.4, 0.8, 55),
            ]
            path = draft._write_user_import_from_events(
                user_dir=user_dir,
                score_id="user_audio_smoke",
                title="Smoke",
                events=events,
                tempo_bpm=100.0,
                preview_sec=45.0,
            )
            self.assertTrue(path.is_file())
            score = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(score["scoreKind"], "userImport")
            self.assertIn("仅前 45 秒预览", score["description"])
            self.assertEqual(score["bpm"], 100)
            self.assertEqual(len(score["notes"]), 3)
            self.assertEqual(score["notes"][0]["midi"], 60)
            self.assertEqual(score["notes"][0]["hand"], "right")
            left = next(n for n in score["notes"] if n["midi"] == 55)
            self.assertEqual(left["hand"], "left")
            right64 = next(n for n in score["notes"] if n["midi"] == 64)
            self.assertEqual(right64["hand"], "right")
            catalog = json.loads(
                (user_dir / "user_catalog.json").read_text(encoding="utf-8")
            )
            self.assertEqual(catalog["songs"][0]["id"], "user_audio_smoke")
            self.assertEqual(catalog["songs"][0]["scoreKind"], "userImport")


if __name__ == "__main__":
    unittest.main()

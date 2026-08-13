# -*- coding: utf-8 -*-
"""Unit tests for demucs decision helpers (no demucs model required)."""
from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "audio_to_practice_draft.py"


def _load():
    spec = importlib.util.spec_from_file_location("audio_to_practice_draft", SCRIPT)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = mod
    spec.loader.exec_module(mod)
    return mod


class DemucsPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = _load()

    def test_user_off(self):
        self.assertEqual(self.m.demucs_plan(want=False, on_path=True), "skip_user_off")
        self.assertEqual(self.m.demucs_plan(want=False, on_path=False), "skip_user_off")

    def test_missing(self):
        self.assertEqual(self.m.demucs_plan(want=True, on_path=False), "skip_missing")

    def test_run(self):
        self.assertEqual(self.m.demucs_plan(want=True, on_path=True), "run")

    def test_honesty_strings(self):
        self.assertIn("含 Demucs 分轨", self.m.HONESTY_DEMUCS)
        self.assertIn("未分轨直转录", self.m.HONESTY_DIRECT)
        self.assertNotIn("formal", self.m.HONESTY_DEMUCS.lower())


if __name__ == "__main__":
    unittest.main()

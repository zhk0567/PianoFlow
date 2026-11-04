"""Dataset from practice_listen JSONL or synthetic batches."""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import torch
from torch.utils.data import Dataset

_SCRIPTS = Path(__file__).resolve().parents[1]
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

from practice_listen_eval.audio_io import read_wav_mono, synth_tone, write_wav_mono  # noqa: E402
from practice_listen_eval.schema_util import LABELS, REPO, load_manifest, resolve_wav  # noqa: E402

from .bp_features import extract_note_frames  # noqa: E402

OUTCOME_INDEX = {lab: i for i, lab in enumerate(LABELS)}
T_FRAMES = 172
MIDI_OFFSET = 21


def _events_to_targets(events: list[dict], guide_audio: bool) -> dict:
    onset = np.zeros(T_FRAMES, dtype=np.float32)
    pitch = np.zeros((T_FRAMES, 88), dtype=np.float32)
    # Map onset_ms → frame assuming ~ window 43844/22050 ≈ 1.99s → 172 frames
    win_ms = 1000.0 * 43844 / 22050.0
    frame_ms = win_ms / T_FRAMES
    # Dominant outcome = first non-hit if any, else hit; for multi-event take mode
    labels = [e["label"] for e in events] or ["hit"]
    # Prefer hardest label for segment head when mixed
    priority = {"wrong": 3, "miss": 2, "extra": 2, "hit": 1}
    labels_sorted = sorted(labels, key=lambda x: priority.get(x, 0), reverse=True)
    outcome = OUTCOME_INDEX[labels_sorted[0]]

    for e in events:
        if e["label"] == "miss":
            continue
        fi = int(float(e["onset_ms"]) / frame_ms)
        if fi < 0 or fi >= T_FRAMES:
            continue
        onset[fi] = 1.0
        # Spread slightly
        for d in (-1, 0, 1):
            j = fi + d
            if 0 <= j < T_FRAMES:
                onset[j] = max(onset[j], 0.5 if d else 1.0)
        midi = int(e["midi"])
        bin_ = midi - MIDI_OFFSET
        if 0 <= bin_ < 88:
            pitch[fi, bin_] = 1.0
    return {
        "onset": onset,
        "pitch": pitch,
        "outcome": outcome,
        "guide": 1.0 if guide_audio else 0.0,
    }


class PracticeListenDataset(Dataset):
    def __init__(self, manifest: Path | None = None, *, synthetic: bool = False, n_synthetic: int = 16):
        self.rows: list[dict] = []
        self._bp_session = None
        if synthetic or manifest is None or not Path(manifest).is_file():
            self.rows = self._make_synthetic(n_synthetic)
        else:
            segs = load_manifest(Path(manifest))
            for seg in segs:
                wav = resolve_wav(seg)
                samples, sr = read_wav_mono(wav)
                feats = extract_note_frames(samples, sr, session=self._session())
                tgt = _events_to_targets(seg.get("events") or [], bool(seg.get("guide_audio")))
                self.rows.append({"feats": feats, **tgt})

    def _session(self):
        if self._bp_session is None:
            try:
                import onnxruntime as ort
                from .bp_features import BP_ONNX

                if BP_ONNX.is_file():
                    self._bp_session = ort.InferenceSession(
                        str(BP_ONNX), providers=["CPUExecutionProvider"]
                    )
            except Exception:
                self._bp_session = False
        return self._bp_session if self._bp_session is not False else None

    def _make_synthetic(self, n: int) -> list[dict]:
        rng = np.random.default_rng(0)
        out = []
        for i in range(n):
            midi = int(rng.integers(48, 72))
            label = LABELS[i % len(LABELS)]
            guide = bool(i % 2)
            # Fake BP-like sparse activation
            feats = rng.random((T_FRAMES, 88), dtype=np.float32) * 0.05
            fi = 20 + (i * 7) % 120
            bin_ = midi - MIDI_OFFSET
            if label != "miss":
                feats[fi, bin_] = 0.9
                if label == "wrong":
                    feats[fi, min(87, bin_ + 1)] = 0.85
                    feats[fi, bin_] = 0.1
            onset = np.zeros(T_FRAMES, dtype=np.float32)
            pitch = np.zeros((T_FRAMES, 88), dtype=np.float32)
            if label != "miss":
                onset[fi] = 1.0
                pitch[fi, bin_ if label != "wrong" else min(87, bin_ + 1)] = 1.0
            out.append(
                {
                    "feats": feats.astype(np.float32),
                    "onset": onset,
                    "pitch": pitch,
                    "outcome": OUTCOME_INDEX[label],
                    "guide": 1.0 if guide else 0.0,
                }
            )
        return out

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, idx: int):
        r = self.rows[idx]
        return {
            "feats": torch.from_numpy(r["feats"]),
            "onset": torch.from_numpy(r["onset"]),
            "pitch": torch.from_numpy(r["pitch"]),
            "outcome": torch.tensor(r["outcome"], dtype=torch.long),
            "guide": torch.tensor(r["guide"], dtype=torch.float32),
        }

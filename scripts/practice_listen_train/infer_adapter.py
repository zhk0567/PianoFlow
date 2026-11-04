"""Eval adapter: BP frames → practice heads → NoteEvent list (ours row)."""
from __future__ import annotations

import sys
import time
from pathlib import Path

import numpy as np
import torch

_SCRIPTS = Path(__file__).resolve().parents[1]
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

from practice_listen_eval.audio_io import read_wav_mono  # noqa: E402
from practice_listen_eval.metrics import NoteEvent  # noqa: E402
from practice_listen_eval.schema_util import REPO  # noqa: E402

from .bp_features import BP_N, BP_SR, extract_note_frames  # noqa: E402
from .model import PracticeListenHeads  # noqa: E402

CKPT = REPO / "artifacts" / "practice_listen" / "practice_listen_heads.pt"
MIDI_OFFSET = 21


def _load_model() -> PracticeListenHeads:
    model = PracticeListenHeads()
    if CKPT.is_file():
        blob = torch.load(CKPT, map_location="cpu", weights_only=True)
        state = blob["model"] if isinstance(blob, dict) and "model" in blob else blob
        model.load_state_dict(state)
    model.eval()
    return model


_MODEL: PracticeListenHeads | None = None


def predict_onsets(wav_path: Path) -> tuple[list[NoteEvent], list[float]]:
    global _MODEL
    if _MODEL is None:
        _MODEL = _load_model()

    samples, sr = read_wav_mono(wav_path)
    t0 = time.perf_counter()
    feats = extract_note_frames(samples, sr)  # (172, 88)
    with torch.no_grad():
        outs = _MODEL(torch.from_numpy(feats).unsqueeze(0))
    infer_ms = (time.perf_counter() - t0) * 1000.0

    onset = outs["onset"][0].numpy()  # (T,)
    pitch = outs["pitch"][0].numpy()  # (T, 88)
    win_sec = BP_N / float(BP_SR)
    frame_hop_sec = win_sec / float(len(onset))

    events: list[NoteEvent] = []
    last_t = -1e9
    # Threshold onset logits
    for fi, logit in enumerate(onset):
        if float(logit) < 0.0:  # sigmoid mid
            continue
        t_ms = 1000.0 * fi * frame_hop_sec
        if t_ms - last_t < 50:
            continue
        bin_ = int(np.argmax(pitch[fi]))
        # Also require some pitch activation in features or head
        if float(pitch[fi, bin_]) < -1.0 and float(feats[fi, bin_]) < 0.2:
            continue
        # Prefer BP feature peak if head is weak
        if float(feats[fi].max()) > 0.3:
            bin_ = int(np.argmax(feats[fi]))
        events.append(NoteEvent(onset_ms=t_ms, midi=bin_ + MIDI_OFFSET, label="hit"))
        last_t = t_ms

    # If heads fired nothing, fall back to feature peaks (still "ours" path)
    if not events:
        for fi in range(feats.shape[0]):
            mx = float(feats[fi].max())
            if mx < 0.42:
                continue
            t_ms = 1000.0 * fi * frame_hop_sec
            if t_ms - last_t < 50:
                continue
            bin_ = int(np.argmax(feats[fi]))
            events.append(NoteEvent(onset_ms=t_ms, midi=bin_ + MIDI_OFFSET, label="hit"))
            last_t = t_ms

    lats = [infer_ms] * max(1, len(events))
    return events, lats

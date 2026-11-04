"""Extract frozen Basic Pitch note frames for training."""
from __future__ import annotations

from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
BP_ONNX = REPO / "assets/models/basic_pitch.onnx"
BP_SR = 22050
BP_N = 43844
BP_HOP_FRAMES = 172


def _resample_linear(x: np.ndarray, src_sr: int, dst_sr: int) -> np.ndarray:
    if src_sr == dst_sr:
        return x.astype(np.float32)
    n_dst = int(round(len(x) * dst_sr / src_sr))
    if n_dst <= 1:
        return np.zeros(1, dtype=np.float32)
    xp = np.linspace(0.0, 1.0, num=len(x), endpoint=False)
    xnew = np.linspace(0.0, 1.0, num=n_dst, endpoint=False)
    return np.interp(xnew, xp, x).astype(np.float32)


def extract_note_frames(
    samples: np.ndarray,
    sr: int,
    *,
    session=None,
    max_frames: int = 172,
) -> np.ndarray:
    """Return (T, 88) note activations from first BP window (or padded)."""
    import onnxruntime as ort

    sess = session
    if sess is None:
        if not BP_ONNX.is_file():
            # Synthetic fallback features for offline CI without model file edge cases
            t = max_frames
            feats = np.zeros((t, 88), dtype=np.float32)
            return feats
        sess = ort.InferenceSession(str(BP_ONNX), providers=["CPUExecutionProvider"])

    audio = _resample_linear(samples, sr, BP_SR)
    chunk = np.zeros(BP_N, dtype=np.float32)
    n = min(BP_N, len(audio))
    chunk[:n] = audio[:n]
    inp = chunk.reshape(1, BP_N, 1).astype(np.float32)
    input_name = sess.get_inputs()[0].name
    out_names = [o.name for o in sess.get_outputs()]
    note_name = "StatefulPartitionedCall:1" if "StatefulPartitionedCall:1" in out_names else out_names[0]
    outs = sess.run([note_name], {input_name: inp})
    note = outs[0][0].astype(np.float32)  # (172, 88)
    if note.shape[0] > max_frames:
        note = note[:max_frames]
    elif note.shape[0] < max_frames:
        pad = np.zeros((max_frames, 88), dtype=np.float32)
        pad[: note.shape[0]] = note
        note = pad
    return note

"""Baseline detectors for practice-listen eval."""
from __future__ import annotations

import time
from pathlib import Path

import numpy as np

from .audio_io import read_wav_mono
from .metrics import NoteEvent

REPO = Path(__file__).resolve().parents[2]
BP_ONNX = REPO / "assets/models/basic_pitch.onnx"
BP_SR = 22050
BP_N = 43844
BP_HOP_FRAMES = 172  # model temporal frames per window
MIDI_OFFSET = 21


def _resample_linear(x: np.ndarray, src_sr: int, dst_sr: int) -> np.ndarray:
    if src_sr == dst_sr:
        return x.astype(np.float32)
    n_dst = int(round(len(x) * dst_sr / src_sr))
    if n_dst <= 1:
        return np.zeros(1, dtype=np.float32)
    xp = np.linspace(0.0, 1.0, num=len(x), endpoint=False)
    xnew = np.linspace(0.0, 1.0, num=n_dst, endpoint=False)
    return np.interp(xnew, xp, x).astype(np.float32)


def yin_onsets(
    samples: np.ndarray,
    sr: int,
    *,
    frame_ms: float = 25.0,
    hop_ms: float = 10.0,
    fmin: float = 65.0,
    fmax: float = 2100.0,
    thresh: float = 0.15,
    amp_thresh: float = 0.02,
) -> list[NoteEvent]:
    """Lightweight YIN-ish pitch tracker with amplitude edge onsets."""
    frame = max(16, int(sr * frame_ms / 1000.0))
    hop = max(8, int(sr * hop_ms / 1000.0))
    tau_min = max(2, int(sr / fmax))
    tau_max = min(frame - 2, int(sr / fmin))
    midis: list[tuple[float, int, float]] = []  # t_ms, midi, amp
    for start in range(0, max(0, len(samples) - frame), hop):
        buf = samples[start : start + frame]
        amp = float(np.sqrt(np.mean(buf * buf)) + 1e-8)
        if amp < amp_thresh:
            continue
        # Difference function
        df = np.zeros(tau_max + 1, dtype=np.float32)
        for tau in range(tau_min, tau_max + 1):
            d = buf[:-tau] - buf[tau:]
            df[tau] = float(np.dot(d, d))
        # Cumulative mean normalized
        cmndf = np.ones_like(df)
        running = 0.0
        for tau in range(1, tau_max + 1):
            running += df[tau]
            cmndf[tau] = df[tau] * tau / running if running > 0 else 1.0
        # Absolute threshold
        tau_est = None
        for tau in range(tau_min, tau_max + 1):
            if cmndf[tau] < thresh:
                while tau + 1 <= tau_max and cmndf[tau + 1] < cmndf[tau]:
                    tau += 1
                tau_est = tau
                break
        if tau_est is None:
            continue
        freq = sr / float(tau_est)
        midi = int(round(69 + 12 * np.log2(freq / 440.0)))
        midi = int(np.clip(midi, 21, 108))
        t_ms = 1000.0 * (start + frame / 2) / sr
        midis.append((t_ms, midi, amp))

    # Edge: amplitude rise or pitch change
    events: list[NoteEvent] = []
    last_midi = None
    last_amp = 0.0
    last_t = -1e9
    for t_ms, midi, amp in midis:
        onset = False
        if last_midi is None:
            onset = True
        elif midi != last_midi and amp > last_amp * 0.8:
            onset = True
        elif amp > last_amp * 1.8 and (t_ms - last_t) > 40:
            onset = True
        if onset and (t_ms - last_t) > 40:
            events.append(NoteEvent(onset_ms=t_ms, midi=midi, label="hit"))
            last_t = t_ms
            last_midi = midi
        last_amp = amp
        if last_midi is None:
            last_midi = midi
    return events


def _bp_session():
    import onnxruntime as ort

    if not BP_ONNX.is_file():
        raise FileNotFoundError(BP_ONNX)
    return ort.InferenceSession(str(BP_ONNX), providers=["CPUExecutionProvider"])


def basic_pitch_onsets(
    samples: np.ndarray,
    sr: int,
    *,
    session=None,
    frame_thresh: float = 0.42,
    relative_thresh: float = 0.60,
    min_gap_ms: float = 50.0,
) -> tuple[list[NoteEvent], list[float]]:
    """Run Basic Pitch ONNX in sliding windows; return events + per-window ms."""
    sess = session or _bp_session()
    audio = _resample_linear(samples, sr, BP_SR)
    latencies: list[float] = []
    # Collect frame peaks → (t_ms, midi, score)
    peaks: list[tuple[float, int, float]] = []
    # Overlap windows by half
    hop = BP_N // 2
    # Seconds per model frame inside a window
    win_sec = BP_N / float(BP_SR)
    frame_hop_sec = win_sec / float(BP_HOP_FRAMES)
    input_name = sess.get_inputs()[0].name
    # Prefer note head StatefulPartitionedCall:1
    out_names = [o.name for o in sess.get_outputs()]
    note_name = "StatefulPartitionedCall:1" if "StatefulPartitionedCall:1" in out_names else out_names[0]

    for start in range(0, max(1, len(audio) - BP_N + 1), hop):
        chunk = audio[start : start + BP_N]
        if len(chunk) < BP_N:
            pad = np.zeros(BP_N, dtype=np.float32)
            pad[: len(chunk)] = chunk
            chunk = pad
        inp = chunk.reshape(1, BP_N, 1).astype(np.float32)
        t0 = time.perf_counter()
        outs = sess.run([note_name], {input_name: inp})
        latencies.append((time.perf_counter() - t0) * 1000.0)
        note = outs[0][0]  # (172, 88)
        # Per-frame peak
        for fi in range(note.shape[0]):
            row = note[fi]
            mx = float(row.max())
            if mx < frame_thresh:
                continue
            for b in range(88):
                v = float(row[b])
                if v < frame_thresh or v < mx * relative_thresh:
                    continue
                t_ms = 1000.0 * ((start / BP_SR) + fi * frame_hop_sec)
                peaks.append((t_ms, b + MIDI_OFFSET, v))

    # NMS-ish: keep rising edges per midi
    peaks.sort(key=lambda x: x[0])
    events: list[NoteEvent] = []
    last_t: dict[int, float] = {}
    for t_ms, midi, _score in peaks:
        prev = last_t.get(midi, -1e9)
        if t_ms - prev < min_gap_ms:
            continue
        # Require a gap or first
        events.append(NoteEvent(onset_ms=t_ms, midi=midi, label="hit"))
        last_t[midi] = t_ms
    return events, latencies


def apply_latch(
    events: list[NoteEvent],
    *,
    refractory_ms: float = 180.0,
) -> list[NoteEvent]:
    """Simplified AttackLatch: same MIDI blocked for refractory_ms after accept."""
    out: list[NoteEvent] = []
    blocked_until: dict[int, float] = {}
    for e in sorted(events, key=lambda x: x.onset_ms):
        until = blocked_until.get(e.midi, -1.0)
        if e.onset_ms < until:
            continue
        out.append(e)
        blocked_until[e.midi] = e.onset_ms + refractory_ms
    return out


def run_baseline(
    name: str,
    wav_path: Path,
    *,
    bp_session=None,
) -> tuple[list[NoteEvent], list[float]]:
    samples, sr = read_wav_mono(wav_path)
    if name == "yin":
        t0 = time.perf_counter()
        ev = yin_onsets(samples, sr)
        # Rough latency proxy: whole-file / n_events
        total = (time.perf_counter() - t0) * 1000.0
        lats = [total / max(1, len(ev))] * max(1, len(ev))
        return ev, lats
    if name == "basic_pitch":
        return basic_pitch_onsets(samples, sr, session=bp_session)
    if name == "basic_pitch_latch":
        ev, lats = basic_pitch_onsets(samples, sr, session=bp_session)
        return apply_latch(ev), lats
    raise ValueError(f"unknown baseline: {name}")

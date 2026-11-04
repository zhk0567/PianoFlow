# -*- coding: utf-8 -*-
"""Campaign F: offline AMT latency / onset-F contrast (Basic Pitch vs optional rtt).

Does **not** replace the live mic engine. Observation only.

Modes:
  1) Synthetic self-check (no external audio): harmonic bursts → BP streaming onset lag.
  2) WAV + ground-truth JSON: measure first-detect latency & note-on F @ 30/50/100ms.
  3) Optional `--rtt-root`: if huispaty/rtt is cloned + deps installed, also score rtt.

Usage (repo root):
  python .\\scripts\\compare_amt_latency.py --self-check
  python .\\scripts\\compare_amt_latency.py --wav clip.wav --gt clip.gt.json
  python .\\scripts\\compare_amt_latency.py --wav clip.wav --gt clip.gt.json --rtt-root ..\\rtt

Ground-truth JSON schema:
  {"onsets": [{"t": 0.50, "midi": 60}, ...]}   # t in seconds
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import time
import wave
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "assets" / "models" / "basic_pitch.onnx"
SR_BP = 22050
AUDIO_N = 43844
N_BINS = 88
MIDI_OFFSET = 21
NOTE_OUT = "StatefulPartitionedCall:1"
INPUT_NAME = "serving_default_input_2:0"
# Match live mic: ~30ms hop, tail=4 newest frames.
LIVE_HOP_SEC = 0.030
LIVE_TAIL = 4
FRAME_THRESH = 0.35  # closer to live gate than offline draft 0.28


@dataclass
class Onset:
    t: float
    midi: int


@dataclass
class EngineReport:
    engine: str
    n_ref: int
    n_est: int
    note_on_f_30ms: float | None
    note_on_f_50ms: float | None
    note_on_f_100ms: float | None
    lag_p50_ms: float | None
    lag_p95_ms: float | None
    lag_mean_ms: float | None
    infer_wall_ms: float | None
    audio_sec: float | None
    notes: list[dict[str, Any]]


def _log(msg: str) -> None:
    print(f"[PianoFlow/amt-compare] {msg}", file=sys.stderr, flush=True)


def midi_to_hz(midi: int) -> float:
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


def synthesize_bursts(
    onsets: list[Onset],
    *,
    sr: int = SR_BP,
    note_dur: float = 0.35,
    pad_end: float = 0.4,
) -> np.ndarray:
    """Additive harmonics (piano-ish) for offline smoke; not a real piano model."""
    if not onsets:
        return np.zeros(int(sr * 0.5), dtype=np.float32)
    end_t = max(o.t for o in onsets) + note_dur + pad_end
    n = int(math.ceil(end_t * sr))
    y = np.zeros(n, dtype=np.float32)
    for o in onsets:
        f0 = midi_to_hz(o.midi)
        i0 = int(o.t * sr)
        length = int(note_dur * sr)
        t = np.arange(length, dtype=np.float32) / sr
        # Attack + decay envelope.
        env = np.minimum(1.0, t / 0.008) * np.exp(-t * 3.5)
        tone = np.zeros(length, dtype=np.float32)
        for h, amp in ((1, 1.0), (2, 0.45), (3, 0.22), (4, 0.12), (5, 0.07)):
            tone += (amp * np.sin(2 * math.pi * f0 * h * t)).astype(np.float32)
        tone *= env.astype(np.float32)
        i1 = min(n, i0 + length)
        y[i0:i1] += tone[: i1 - i0]
    peak = float(np.max(np.abs(y))) + 1e-9
    return (y / peak * 0.85).astype(np.float32)


def load_wav_mono(path: Path, target_sr: int) -> np.ndarray:
    with wave.open(str(path), "rb") as w:
        ch = w.getnchannels()
        sr = w.getframerate()
        width = w.getsampwidth()
        raw = w.readframes(w.getnframes())
    if width == 2:
        samples = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    elif width == 1:
        samples = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128) / 128.0
    else:
        raise ValueError(f"unsupported sample width {width}")
    if ch == 2:
        samples = samples.reshape(-1, 2).mean(axis=1)
    if sr != target_sr:
        x = np.linspace(0, 1, num=len(samples), endpoint=False)
        n2 = int(len(samples) * target_sr / sr)
        samples = np.interp(
            np.linspace(0, 1, num=n2, endpoint=False), x, samples
        ).astype(np.float32)
    return samples


def load_gt(path: Path) -> list[Onset]:
    data = json.loads(path.read_text(encoding="utf-8"))
    items = data["onsets"] if isinstance(data, dict) else data
    out: list[Onset] = []
    for it in items:
        out.append(Onset(t=float(it["t"]), midi=int(it["midi"])))
    out.sort(key=lambda o: (o.t, o.midi))
    return out


def write_wav(path: Path, audio: np.ndarray, sr: int = SR_BP) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(audio * 32767.0, -32768, 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def match_onsets(
    ref: list[Onset],
    est: list[Onset],
    *,
    tol_sec: float,
    allow_octave: bool = False,
) -> tuple[float, list[float]]:
    """Greedy 1:1 note-on F and lag list (est - ref) for matched pairs."""
    if not ref and not est:
        return 1.0, []
    if not ref or not est:
        return 0.0, []
    used = [False] * len(est)
    hits = 0
    lags: list[float] = []
    for r in ref:
        best_j = -1
        best_abs = tol_sec + 1.0
        for j, e in enumerate(est):
            if used[j]:
                continue
            dt = abs(e.t - r.t)
            if dt > tol_sec or dt >= best_abs:
                continue
            ok = e.midi == r.midi
            if allow_octave and not ok:
                ok = abs(e.midi - r.midi) == 12
            if not ok:
                continue
            best_abs = dt
            best_j = j
        if best_j >= 0:
            used[best_j] = True
            hits += 1
            lags.append(est[best_j].t - r.t)
    prec = hits / len(est)
    rec = hits / len(ref)
    if prec + rec == 0:
        return 0.0, lags
    return 2 * prec * rec / (prec + rec), lags


def percentile_ms(lags_sec: list[float], p: float) -> float | None:
    if not lags_sec:
        return None
    ms = sorted(x * 1000.0 for x in lags_sec)
    if len(ms) == 1:
        return ms[0]
    rank = (p / 100.0) * (len(ms) - 1)
    lo = int(math.floor(rank))
    hi = int(math.ceil(rank))
    if lo == hi:
        return ms[lo]
    t = rank - lo
    return ms[lo] * (1 - t) + ms[hi] * t


def build_report(
    engine: str,
    ref: list[Onset],
    est: list[Onset],
    *,
    infer_wall_ms: float | None,
    audio_sec: float | None,
) -> EngineReport:
    f30, lags = match_onsets(ref, est, tol_sec=0.03)
    f50, _ = match_onsets(ref, est, tol_sec=0.05)
    f100, _ = match_onsets(ref, est, tol_sec=0.10)
    # Latency stats use 100ms matching window (product-ish), still report signed lag.
    _, lags100 = match_onsets(ref, est, tol_sec=0.10)
    mean = (sum(lags100) / len(lags100) * 1000.0) if lags100 else None
    return EngineReport(
        engine=engine,
        n_ref=len(ref),
        n_est=len(est),
        note_on_f_30ms=round(f30, 4),
        note_on_f_50ms=round(f50, 4),
        note_on_f_100ms=round(f100, 4),
        lag_p50_ms=_round_opt(percentile_ms(lags100, 50)),
        lag_p95_ms=_round_opt(percentile_ms(lags100, 95)),
        lag_mean_ms=_round_opt(mean),
        infer_wall_ms=_round_opt(infer_wall_ms),
        audio_sec=_round_opt(audio_sec),
        notes=[{"t": round(e.t, 4), "midi": e.midi} for e in est],
    )


def _round_opt(v: float | None, nd: int = 2) -> float | None:
    if v is None:
        return None
    return round(float(v), nd)


# ---- Basic Pitch streaming (live-like) ------------------------------------


def _select_notes(scores: np.ndarray, frame_thresh: float = FRAME_THRESH) -> set[int]:
    peaks: list[tuple[float, int]] = []
    for i, s in enumerate(scores):
        if s < frame_thresh:
            continue
        peaks.append((float(s), MIDI_OFFSET + i))
    if not peaks:
        return set()
    peaks.sort(reverse=True)
    top = peaks[0][0]
    return {midi for s, midi in peaks if s >= top * 0.5}


def _infer_window(session, audio_chunk: np.ndarray, *, tail: int) -> set[int]:
    window = np.zeros((1, AUDIO_N, 1), dtype=np.float32)
    n = len(audio_chunk)
    if n >= AUDIO_N:
        window[0, :, 0] = audio_chunk[-AUDIO_N:]
    elif n > 0:
        window[0, AUDIO_N - n :, 0] = audio_chunk
    outs = session.run([NOTE_OUT], {INPUT_NAME: window})
    frames = outs[0][0]
    t = min(tail, frames.shape[0])
    scores = frames[-t:].mean(axis=0)
    return _select_notes(scores)


def bp_stream_onsets(
    audio: np.ndarray,
    *,
    hop_sec: float = LIVE_HOP_SEC,
    tail: int = LIVE_TAIL,
) -> tuple[list[Onset], float]:
    """Causal rolling-context BP; emit note when MIDI newly appears (edge)."""
    import onnxruntime as ort

    if not MODEL.is_file():
        raise FileNotFoundError(f"missing {MODEL}")
    sess = ort.InferenceSession(str(MODEL), providers=["CPUExecutionProvider"])
    hop = max(1, int(SR_BP * hop_sec))
    active: set[int] = set()
    events: list[Onset] = []
    t0 = time.perf_counter()
    i = hop
    while i <= len(audio):
        end = i
        start = max(0, end - AUDIO_N)
        chunk = audio[start:end]
        tail_pcm = audio[max(0, end - hop) : end]
        rms = float(np.sqrt(np.mean(np.square(tail_pcm)))) if len(tail_pcm) else 0.0
        notes = set() if rms < 0.006 else _infer_window(sess, chunk, tail=tail)
        now = end / SR_BP
        for m in sorted(notes - active):
            events.append(Onset(t=now, midi=m))
        active = notes
        i += hop
    wall = (time.perf_counter() - t0) * 1000.0
    events.sort(key=lambda o: (o.t, o.midi))
    return events, wall


# ---- Optional rtt ---------------------------------------------------------


def rtt_onsets(
    audio_16k: np.ndarray,
    *,
    rtt_root: Path,
) -> tuple[list[Onset], float]:
    """Run huispaty/rtt PianoTranscription if checkout + deps exist."""
    src = rtt_root / "src"
    ckpt = rtt_root / "ckpts" / "CustomAMT.ckpt"
    if not src.is_dir():
        raise FileNotFoundError(f"rtt src missing: {src}")
    if not ckpt.is_file():
        raise FileNotFoundError(f"rtt checkpoint missing: {ckpt}")
    sys.path.insert(0, str(src))
    try:
        import torch
        from inference import PianoTranscription  # type: ignore
    except Exception as e:
        raise RuntimeError(
            "rtt import failed (need torch/lightning/librosa per rtt requirements.txt)"
        ) from e

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    t0 = time.perf_counter()
    transcriptor = PianoTranscription(
        checkpoint_path=str(ckpt),
        device=device,
    )
    result = transcriptor.transcribe(audio_16k.astype(np.float32))
    wall = (time.perf_counter() - t0) * 1000.0
    events: list[Onset] = []
    for ev in result.get("est_note_events") or []:
        # rtt postprocessor typically: onset_time, offset_time, midi_note, ...
        if isinstance(ev, dict):
            t = float(ev.get("onset_time", ev.get("onset", ev.get("start_time", 0))))
            midi = int(ev.get("midi_note", ev.get("midi", ev.get("pitch", 0))))
        else:
            # tuple/list fallback
            t = float(ev[0])
            midi = int(ev[2] if len(ev) > 2 else ev[1])
        if 21 <= midi <= 108:
            events.append(Onset(t=t, midi=midi))
    events.sort(key=lambda o: (o.t, o.midi))
    return events, wall


def resample_linear(audio: np.ndarray, src_sr: int, dst_sr: int) -> np.ndarray:
    if src_sr == dst_sr:
        return audio.astype(np.float32)
    x = np.linspace(0, 1, num=len(audio), endpoint=False)
    n2 = max(1, int(len(audio) * dst_sr / src_sr))
    return np.interp(np.linspace(0, 1, num=n2, endpoint=False), x, audio).astype(
        np.float32
    )


def default_self_check_gt() -> list[Onset]:
    return [
        Onset(0.40, 60),
        Onset(0.90, 64),
        Onset(1.40, 67),
        Onset(1.90, 60),
        Onset(2.40, 72),
    ]


def run_compare(
    *,
    audio_bp: np.ndarray,
    ref: list[Onset],
    rtt_root: Path | None,
) -> dict[str, Any]:
    reports: list[EngineReport] = []
    audio_sec = len(audio_bp) / SR_BP

    _log(f"BP streaming hop={LIVE_HOP_SEC}s tail={LIVE_TAIL} audio={audio_sec:.2f}s")
    est_bp, wall_bp = bp_stream_onsets(audio_bp)
    reports.append(
        build_report(
            "basic_pitch_stream",
            ref,
            est_bp,
            infer_wall_ms=wall_bp,
            audio_sec=audio_sec,
        )
    )
    _log(
        f"BP est={len(est_bp)} F100={reports[-1].note_on_f_100ms} "
        f"lag_p50={reports[-1].lag_p50_ms}ms wall={wall_bp:.0f}ms"
    )

    if rtt_root is not None:
        try:
            audio_16k = resample_linear(audio_bp, SR_BP, 16000)
            est_rtt, wall_rtt = rtt_onsets(audio_16k, rtt_root=rtt_root)
            reports.append(
                build_report(
                    "rtt",
                    ref,
                    est_rtt,
                    infer_wall_ms=wall_rtt,
                    audio_sec=len(audio_16k) / 16000.0,
                )
            )
            _log(
                f"rtt est={len(est_rtt)} F100={reports[-1].note_on_f_100ms} "
                f"lag_p50={reports[-1].lag_p50_ms}ms wall={wall_rtt:.0f}ms"
            )
        except Exception as e:
            _log(f"rtt skipped: {e}")
            reports.append(
                EngineReport(
                    engine="rtt",
                    n_ref=len(ref),
                    n_est=0,
                    note_on_f_30ms=None,
                    note_on_f_50ms=None,
                    note_on_f_100ms=None,
                    lag_p50_ms=None,
                    lag_p95_ms=None,
                    lag_mean_ms=None,
                    infer_wall_ms=None,
                    audio_sec=None,
                    notes=[],
                )
            )

    return {
        "schema": "pianoflow.amt_compare.v1",
        "ref": [{"t": o.t, "midi": o.midi} for o in ref],
        "engines": [asdict(r) for r in reports],
        "decision_gate": {
            "replace_bp_only_if": [
                "rtt note-on F@50ms >= BP on same clips",
                "rtt lag_p95_ms clearly lower AND mobile/onnx path feasible",
                "no regression on Wait/cue-bleed product path",
            ],
            "status": "observe_only",
        },
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="AMT latency contrast (Campaign F)")
    ap.add_argument("--self-check", action="store_true", help="synthetic harmonic bursts")
    ap.add_argument("--wav", type=Path, help="mono/stereo PCM WAV")
    ap.add_argument("--gt", type=Path, help="ground-truth onsets JSON")
    ap.add_argument(
        "--rtt-root",
        type=Path,
        default=None,
        help="path to cloned https://github.com/huispaty/rtt (optional)",
    )
    ap.add_argument(
        "--out",
        type=Path,
        default=None,
        help="write JSON report (default: stdout only summary)",
    )
    ap.add_argument(
        "--write-synth-wav",
        type=Path,
        default=None,
        help="with --self-check, also dump the synthetic WAV",
    )
    args = ap.parse_args(argv)

    if args.self_check:
        ref = default_self_check_gt()
        audio = synthesize_bursts(ref)
        if args.write_synth_wav:
            write_wav(args.write_synth_wav, audio)
            _log(f"wrote {args.write_synth_wav}")
    else:
        if not args.wav or not args.gt:
            ap.error("need --self-check, or both --wav and --gt")
        ref = load_gt(args.gt)
        audio = load_wav_mono(args.wav, SR_BP)

    report = run_compare(audio_bp=audio, ref=ref, rtt_root=args.rtt_root)
    text = json.dumps(report, ensure_ascii=False, indent=2)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text + "\n", encoding="utf-8")
        _log(f"wrote {args.out}")
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

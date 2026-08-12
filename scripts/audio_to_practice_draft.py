# -*- coding: utf-8 -*-
"""Audio → practice draft (userImport only, seconds-level for short clips).

Primary path (no PyPI basic-pitch needed):
  wav → assets/models/basic_pitch.onnx (onnxruntime) → events → score JSON + user_catalog
  (same process; no MIDI / MusicXML subprocess round-trip)

Honesty: NEVER formal.

Usage (PowerShell, repo root):
  python .\\scripts\\audio_to_practice_draft.py --input clip.wav --user-import-dir PATH
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "assets" / "models" / "basic_pitch.onnx"
HONESTY = (
    "工坊音频转录草稿（非正式精确谱；本地 Basic Pitch ONNX→练习 JSON，"
    "禁止冒充正式谱）。短片段目标秒级；过长音频会截取前段预览。"
)

AUDIO_N = 43844
SR = 22050
N_BINS = 88
MIDI_OFFSET = 21
NOTE_OUT = "StatefulPartitionedCall:1"
INPUT_NAME = "serving_default_input_2:0"
PARTIALS = (12, 19, 24, 28, 31, 36)


def _log(msg: str) -> None:
    print(f"[PianoFlow/audio-draft] {msg}", flush=True)


def _load_mono_22050(path: Path) -> np.ndarray:
    """Load audio as float32 mono @22050. Prefer soundfile/librosa; fallback wav."""
    try:
        import soundfile as sf

        data, sr = sf.read(str(path), always_2d=False)
        data = np.asarray(data, dtype=np.float32)
        if data.ndim > 1:
            data = data.mean(axis=1)
        if sr != SR:
            # linear resample
            x = np.linspace(0, 1, num=len(data), endpoint=False)
            n = int(len(data) * SR / sr)
            data = np.interp(np.linspace(0, 1, num=n, endpoint=False), x, data).astype(
                np.float32
            )
        return data
    except Exception:
        pass
    # wave PCM only
    with wave.open(str(path), "rb") as w:
        assert w.getnchannels() in (1, 2)
        sr = w.getframerate()
        n = w.getnframes()
        raw = w.readframes(n)
        width = w.getsampwidth()
        if width == 2:
            samples = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
        elif width == 1:
            samples = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128) / 128.0
        else:
            raise SystemExit(f"不支持的 WAV 位深: {width}")
        ch = w.getnchannels()
        if ch == 2:
            samples = samples.reshape(-1, 2).mean(axis=1)
        if sr != SR:
            x = np.linspace(0, 1, num=len(samples), endpoint=False)
            n2 = int(len(samples) * SR / sr)
            samples = np.interp(
                np.linspace(0, 1, num=n2, endpoint=False), x, samples
            ).astype(np.float32)
        return samples


def _select_notes(scores: np.ndarray, frame_thresh=0.28, relative=0.5) -> set[int]:
    """scores: (88,) mean activations. Offline draft uses softer thresh than live mic."""
    peaks = []
    for i, s in enumerate(scores):
        if s < frame_thresh:
            continue
        peaks.append((float(s), MIDI_OFFSET + i))
    if not peaks:
        return set()
    peaks.sort(reverse=True)
    top = peaks[0][0]
    kept = [midi for s, midi in peaks if s >= top * relative]
    strong = set(kept)
    out: set[int] = set()
    for midi in sorted(kept):
        ghost = False
        for p in PARTIALS:
            if (midi - p) in strong:
                ghost = True
                break
        if not ghost:
            out.add(midi)
    return out


def _infer_window(session, audio_chunk: np.ndarray) -> set[int]:
    window = np.zeros((1, AUDIO_N, 1), dtype=np.float32)
    n = len(audio_chunk)
    if n >= AUDIO_N:
        window[0, :, 0] = audio_chunk[-AUDIO_N:]
    elif n > 0:
        window[0, AUDIO_N - n :, 0] = audio_chunk
    outs = session.run([NOTE_OUT], {INPUT_NAME: window})
    frames = outs[0][0]  # (172, 88)
    # offline: use more frames than live (live uses tail=4 for latency)
    tail = frames[-12:].mean(axis=0)
    return _select_notes(tail)


def _emphasize_piano_band(audio: np.ndarray) -> np.ndarray:
    """Simple STFT band focus (≈80–3500 Hz). Not true stem separation."""
    if len(audio) < 2048:
        return audio
    n_fft = 2048
    hop = 512
    window = np.hanning(n_fft).astype(np.float32)
    # zero-pad
    pad = (-len(audio)) % hop
    x = np.concatenate([audio, np.zeros(pad, dtype=np.float32)])
    out = np.zeros_like(x)
    norm = np.zeros_like(x)
    freqs = np.fft.rfftfreq(n_fft, d=1.0 / SR)
    # soft mask: boost piano-ish band, attenuate extremes
    mask = np.ones_like(freqs, dtype=np.float32)
    mask[(freqs < 80) | (freqs > 3500)] = 0.25
    mask[(freqs >= 200) & (freqs <= 2000)] = 1.35
    for i in range(0, len(x) - n_fft + 1, hop):
        frame = x[i : i + n_fft] * window
        spec = np.fft.rfft(frame)
        spec *= mask
        recon = np.fft.irfft(spec, n=n_fft).real.astype(np.float32)
        out[i : i + n_fft] += recon * window
        norm[i : i + n_fft] += window * window
    norm = np.maximum(norm, 1e-6)
    y = out / norm
    peak = float(np.max(np.abs(y))) + 1e-9
    y = (y / peak * 0.9).astype(np.float32)
    return y[: len(audio)]


def _transcribe_onnx(audio: np.ndarray, hop_sec: float = 0.4) -> list[tuple[float, float, int]]:
    import onnxruntime as ort

    if not MODEL.is_file():
        raise SystemExit(f"缺少模型: {MODEL}")
    sess = ort.InferenceSession(str(MODEL), providers=["CPUExecutionProvider"])
    hop = max(1, int(SR * hop_sec))
    active: dict[int, float] = {}
    events: list[tuple[float, float, int]] = []
    i = 0
    total = max(1, (len(audio) + hop - 1) // hop)
    step = 0
    while i < len(audio):
        end = min(len(audio), i + hop)
        # Full model context ending at `end` (not just the hop slice).
        start = max(0, end - AUDIO_N)
        context = audio[start:end]
        notes = _infer_window(sess, context)
        now = i / SR
        for m in [m for m in active if m not in notes]:
            st = active.pop(m)
            events.append((st, max(st + 0.08, now), m))
        for m in notes:
            if m not in active:
                active[m] = now
        i += hop
        step += 1
        if step == 1 or step == total or step % max(1, total // 8) == 0:
            _log(f"progress={step}/{total}")
    end_t = len(audio) / SR
    for m, st in list(active.items()):
        events.append((st, max(st + 0.1, end_t), m))
    events.sort(key=lambda e: (e[0], e[2]))
    return events


def _write_user_import_from_events(
    *,
    user_dir: Path,
    score_id: str,
    title: str,
    events: list[tuple[float, float, int]],
    tempo_bpm: float = 100.0,
) -> Path:
    """Write practice JSON + user_catalog in-process (no MIDI/MusicXML subprocess)."""
    bpm = max(40, int(round(tempo_bpm)))
    notes: list[dict] = []
    for st, en, midi in events:
        if en <= st:
            en = st + 0.1
        start_b = st * bpm / 60.0
        dur_b = max(0.125, (en - st) * bpm / 60.0)
        notes.append(
            {
                "midi": int(midi),
                "start": round(start_b, 4),
                "duration": round(dur_b, 4),
                "hand": "right" if midi >= 60 else "left",
            }
        )
    notes.sort(key=lambda n: (n["start"], n["midi"]))
    duration_beats = 0.0
    for n in notes:
        duration_beats = max(duration_beats, n["start"] + n["duration"])

    score = {
        "id": score_id,
        "title": title,
        "bpm": bpm,
        "timeSignature": {"num": 4, "den": 4},
        "keySignature": 0,
        "notes": notes,
        "scoreKind": "userImport",
        "description": HONESTY,
    }
    json_path = user_dir / f"{score_id}.json"
    json_path.write_text(
        json.dumps(score, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    catalog_path = user_dir / "user_catalog.json"
    if catalog_path.exists():
        data = json.loads(catalog_path.read_text(encoding="utf-8"))
    else:
        data = {"songs": []}
    songs = data.get("songs") or []
    duration_hint = max(8, int(round(duration_beats * 60 / max(bpm, 1))))
    entry = {
        "id": score_id,
        "title": title,
        "artist": "音频转录草稿",
        "genre": "Classical",
        "difficulty": 3,
        "bpm": bpm,
        "asset": str(json_path.resolve()),
        "description": HONESTY,
        "durationHint": duration_hint,
        "scoreKind": "userImport",
    }
    replaced = False
    for i, s in enumerate(songs):
        if s.get("id") == score_id:
            songs[i] = entry
            replaced = True
            break
    if not replaced:
        songs.append(entry)
    data["songs"] = songs
    catalog_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    _log(
        f"user-import wrote {json_path.name} notes={len(notes)} "
        f"bpm={bpm} catalog={'updated' if replaced else 'added'}"
    )
    return json_path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", type=Path, required=True)
    ap.add_argument("--title", default="")
    ap.add_argument("--id", default="")
    ap.add_argument("--user-import-dir", type=Path, required=True)
    ap.add_argument("--hop-sec", type=float, default=0.4,
                    help="ONNX 滑窗步长秒（练习草稿默认 0.4，短音更糊但更快）")
    ap.add_argument(
        "--max-sec",
        type=float,
        default=45.0,
        help="超过此时长只转录前段（秒级演示；0=不截断）",
    )
    ap.add_argument(
        "--emphasize-piano",
        action="store_true",
        help="简易钢琴频段强调（非真分轨），利于流行曲混音",
    )
    args = ap.parse_args()

    audio_path = args.input.resolve()
    if not audio_path.is_file():
        _log(f"找不到文件: {audio_path}")
        return 1

    t0 = time.perf_counter()
    stem = "".join(c if c.isalnum() or c in "_-" else "_" for c in audio_path.stem.lower())
    score_id = (args.id.strip() or f"user_audio_{stem}")[:48]
    title = args.title.strip() or audio_path.stem
    user_dir = args.user_import_dir.resolve()
    user_dir.mkdir(parents=True, exist_ok=True)

    _log(f"loading {audio_path.name} …")
    audio = _load_mono_22050(audio_path)
    if args.emphasize_piano:
        _log("emphasize-piano band (not true stem separation)")
        audio = _emphasize_piano_band(audio)
    max_sec = float(args.max_sec)
    if max_sec > 0:
        max_n = int(SR * max_sec)
        if len(audio) > max_n:
            _log(f"truncate {len(audio)/SR:.1f}s → {max_sec:.0f}s preview (秒级约束)")
            audio = audio[:max_n]
    _log(f"samples={len(audio)} dur={len(audio)/SR:.2f}s → ONNX transcribe")
    events = _transcribe_onnx(audio, hop_sec=args.hop_sec)
    if not events:
        _log("未检测到音符（可换更清晰钢琴短片段）")
        return 3
    _log(f"notes={len(events)}")
    _write_user_import_from_events(
        user_dir=user_dir,
        score_id=score_id,
        title=title,
        events=events,
    )
    elapsed = time.perf_counter() - t0
    _log(f"OK id={score_id} elapsed={elapsed:.2f}s user_dir={user_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

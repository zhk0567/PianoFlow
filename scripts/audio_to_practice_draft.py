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
HONESTY_BASE = (
    "工坊音频转录草稿（非正式精确谱；本地 Basic Pitch ONNX→练习 JSON，"
    "禁止冒充正式谱）。短片段目标秒级；过长音频会截取前段预览。"
)
HONESTY_DEMUCS = (
    "工坊音频转录草稿（含 Demucs 分轨；非正式精确谱；"
    "本地 Basic Pitch ONNX→练习 JSON，禁止冒充正式谱）。"
    "短片段目标秒级；过长音频会截取前段预览。"
)
HONESTY_DIRECT = (
    "工坊音频转录草稿（未分轨直转录；非正式精确谱；"
    "本地 Basic Pitch ONNX→练习 JSON，禁止冒充正式谱）。"
    "短片段目标秒级；过长音频会截取前段预览。"
)

AUDIO_N = 43844
SR = 22050
N_BINS = 88
MIDI_OFFSET = 21
NOTE_OUT = "StatefulPartitionedCall:1"
INPUT_NAME = "serving_default_input_2:0"
PARTIALS = (12, 19, 24, 28, 31, 36)


def _log(msg: str) -> None:
    # Serve mode: stdout is JSON-only; logs must not break the line protocol.
    print(f"[PianoFlow/audio-draft] {msg}", file=sys.stderr, flush=True)


def _read_pcm_wav_mono(path: Path) -> np.ndarray:
    """Read 8/16-bit PCM WAV → float32 mono, resample to SR if needed."""
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
            raise ValueError(f"不支持的 WAV 位深: {width}")
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


def _ffmpeg_decode_mono_22050(path: Path) -> np.ndarray:
    """Decode any ffmpeg-supported file → mono float32 @SR via temp PCM WAV."""
    import shutil
    import subprocess
    import tempfile

    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("PATH 中未找到 ffmpeg")
    with tempfile.TemporaryDirectory(prefix="pf_audio_") as td:
        out = Path(td) / "decode.wav"
        cmd = [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(path),
            "-ac",
            "1",
            "-ar",
            str(SR),
            "-sample_fmt",
            "s16",
            str(out),
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if proc.returncode != 0 or not out.is_file():
            err = (proc.stderr or proc.stdout or "").strip()[:400]
            raise RuntimeError(f"ffmpeg 失败 (code={proc.returncode}): {err}")
        return _read_pcm_wav_mono(out)


def _load_mono_22050(path: Path) -> np.ndarray:
    """Load audio as float32 mono @22050. soundfile → PCM WAV → ffmpeg."""
    sf_err: Exception | None = None
    wav_err: Exception | None = None
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
        _log("decode=soundfile")
        print("progress=decode=soundfile", file=sys.stderr, flush=True)
        return data
    except Exception as e:
        sf_err = e
        _log(f"soundfile 不可用/失败（{type(e).__name__}），尝试 PCM WAV…")
    try:
        samples = _read_pcm_wav_mono(path)
        _log("decode=pcm_wav")
        print("progress=decode=pcm_wav", file=sys.stderr, flush=True)
        return samples
    except Exception as e:
        wav_err = e
        _log(f"PCM WAV 失败（{type(e).__name__}），尝试 ffmpeg…")
    try:
        samples = _ffmpeg_decode_mono_22050(path)
        _log("decode=ffmpeg")
        print("progress=decode=ffmpeg", file=sys.stderr, flush=True)
        return samples
    except Exception as e:
        hint = (
            "请安装 soundfile（pip install soundfile），或安装 ffmpeg 并加入 PATH，"
            "或改用 16-bit PCM WAV。"
        )
        parts = [f"无法解码音频 {path.name}"]
        if sf_err is not None:
            parts.append(f"soundfile：{sf_err}")
        if wav_err is not None:
            parts.append(f"PCM WAV：{wav_err}")
        parts.append(f"ffmpeg：{e}")
        parts.append(hint)
        raise SystemExit("；".join(parts)) from e


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


def demucs_available() -> bool:
    """True if `demucs` CLI or `python -m demucs` is usable (no model download here)."""
    import shutil
    import subprocess

    if shutil.which("demucs"):
        return True
    try:
        proc = subprocess.run(
            [sys.executable, "-m", "demucs", "-h"],
            capture_output=True,
            text=True,
            check=False,
            timeout=20,
        )
        return proc.returncode == 0
    except Exception:
        return False


def demucs_plan(*, want: bool, on_path: bool | None = None) -> str:
    """Pure decision helper for tests: run | skip_user_off | skip_missing."""
    if not want:
        return "skip_user_off"
    available = demucs_available() if on_path is None else on_path
    if not available:
        return "skip_missing"
    return "run"


def _try_demucs_instrumental(audio_path: Path) -> tuple[Path | None, str]:
    """Run demucs --two-stems=vocals; return no_vocals wav path or (None, reason).

    Does not download models; failure falls back to caller.
    """
    import shutil
    import subprocess
    import tempfile

    plan = demucs_plan(want=True)
    if plan == "skip_missing":
        msg = "无 demucs（PATH/`python -m demucs`），跳过分轨，直转录"
        _log(msg)
        print("progress=demucs=skip_missing", file=sys.stderr, flush=True)
        return None, msg

    out_root = Path(tempfile.mkdtemp(prefix="pf_demucs_"))
    cmd: list[str]
    if shutil.which("demucs"):
        cmd = ["demucs", "--two-stems=vocals", "-o", str(out_root), str(audio_path)]
    else:
        cmd = [
            sys.executable,
            "-m",
            "demucs",
            "--two-stems=vocals",
            "-o",
            str(out_root),
            str(audio_path),
        ]
    _log(f"demucs start: {' '.join(cmd)}")
    print("progress=demucs=running", file=sys.stderr, flush=True)
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False,
            timeout=600,
        )
    except Exception as e:
        msg = f"demucs 启动失败，回退原音频：{e}"
        _log(msg)
        print("progress=demucs=fallback", file=sys.stderr, flush=True)
        return None, msg

    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip()[:400]
        msg = f"demucs 失败(code={proc.returncode})，回退原音频：{err}"
        _log(msg)
        print("progress=demucs=fallback", file=sys.stderr, flush=True)
        return None, msg

    # Expected: out_root/<model>/<track>/no_vocals.wav (or .mp3)
    candidates = sorted(out_root.rglob("no_vocals.*"))
    wavs = [c for c in candidates if c.suffix.lower() in {".wav", ".flac", ".mp3"}]
    if not wavs:
        msg = "demucs 未产出 no_vocals，回退原音频"
        _log(msg)
        print("progress=demucs=fallback", file=sys.stderr, flush=True)
        return None, msg
    chosen = wavs[0]
    _log(f"demucs stem={chosen}")
    print("progress=demucs=ok", file=sys.stderr, flush=True)
    return chosen, "含 Demucs 分轨（no_vocals）"


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
    sess = _ort_session()
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
        # Skip ORT on near-silence (still clears active notes).
        tail = audio[i:end]
        rms = float(np.sqrt(np.mean(np.square(tail)))) if len(tail) else 0.0
        if rms < 0.006:
            notes: set[int] = set()
        else:
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


_ORT_SESS = None


def _ort_session():
    """Reuse one InferenceSession across jobs (serve mode / warm imports)."""
    global _ORT_SESS
    import onnxruntime as ort

    if _ORT_SESS is not None:
        return _ORT_SESS
    if not MODEL.is_file():
        raise SystemExit(f"缺少模型: {MODEL}")
    _log(f"ORT loading {MODEL.name} …")
    t0 = time.perf_counter()
    _ORT_SESS = ort.InferenceSession(str(MODEL), providers=["CPUExecutionProvider"])
    _log(f"ORT ready in {time.perf_counter() - t0:.2f}s")
    return _ORT_SESS


def _write_user_import_from_events(
    *,
    user_dir: Path,
    score_id: str,
    title: str,
    events: list[tuple[float, float, int]],
    tempo_bpm: float = 100.0,
    preview_sec: float | None = None,
    honesty: str = HONESTY_DIRECT,
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

    desc = honesty
    if preview_sec is not None and preview_sec > 0:
        desc = f"{honesty}；仅前 {int(round(preview_sec))} 秒预览（完整曲目未转录）"

    score = {
        "id": score_id,
        "title": title,
        "bpm": bpm,
        "timeSignature": {"num": 4, "den": 4},
        "keySignature": 0,
        "notes": notes,
        "scoreKind": "userImport",
        "description": desc,
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
        "description": desc,
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


def run_transcribe_job(
    *,
    audio_path: Path,
    user_dir: Path,
    score_id: str,
    title: str,
    hop_sec: float = 0.4,
    max_sec: float = 45.0,
    emphasize_piano: bool = False,
    use_demucs: bool = False,
) -> dict:
    """Load → optional Demucs → ONNX → write userImport. Returns result dict."""
    t0 = time.perf_counter()
    if not audio_path.is_file():
        return {"ok": False, "error": f"找不到文件: {audio_path}"}
    user_dir.mkdir(parents=True, exist_ok=True)

    source_path = audio_path
    demucs_used = False
    if use_demucs:
        stem_path, demucs_msg = _try_demucs_instrumental(audio_path)
        if stem_path is not None:
            source_path = stem_path
            demucs_used = True
            _log(demucs_msg)
        else:
            _log(demucs_msg)
    else:
        _log("demucs=off（用户关闭）")
        print("progress=demucs=skip_user_off", file=sys.stderr, flush=True)

    honesty = HONESTY_DEMUCS if demucs_used else HONESTY_DIRECT
    _log(f"loading {source_path.name} …")
    try:
        audio = _load_mono_22050(source_path)
    except SystemExit as e:
        return {"ok": False, "error": str(e)}
    except Exception as e:
        return {"ok": False, "error": f"解码失败: {e}"}
    if emphasize_piano:
        _log("emphasize-piano band (not true stem separation)")
        audio = _emphasize_piano_band(audio)
    preview_sec: float | None = None
    if max_sec > 0:
        max_n = int(SR * max_sec)
        if len(audio) > max_n:
            _log(f"truncate {len(audio)/SR:.1f}s → {max_sec:.0f}s preview (秒级约束)")
            audio = audio[:max_n]
            preview_sec = max_sec
    _log(f"samples={len(audio)} dur={len(audio)/SR:.2f}s → ONNX transcribe")
    try:
        events = _transcribe_onnx(audio, hop_sec=hop_sec)
    except SystemExit as e:
        return {"ok": False, "error": str(e)}
    except Exception as e:
        return {"ok": False, "error": f"ONNX 失败: {e}"}
    if not events:
        return {"ok": False, "error": "未检测到音符（可换更清晰钢琴短片段）", "code": 3}
    _log(f"notes={len(events)}")
    _write_user_import_from_events(
        user_dir=user_dir,
        score_id=score_id,
        title=title,
        events=events,
        preview_sec=preview_sec,
        honesty=honesty,
    )
    elapsed_ms = int((time.perf_counter() - t0) * 1000)
    _log(f"OK id={score_id} elapsed={elapsed_ms/1000:.2f}s demucs={demucs_used} user_dir={user_dir}")
    return {
        "ok": True,
        "score_id": score_id,
        "elapsed_ms": elapsed_ms,
        "notes": len(events),
        "demucs": demucs_used,
    }


def serve() -> int:
    """stdin JSON lines → stdout JSON results; ORT session kept warm."""
    try:
        _ort_session()
    except SystemExit as e:
        print(json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False), flush=True)
        return 1
    print(json.dumps({"ok": True, "ready": True}, ensure_ascii=False), flush=True)
    for raw in sys.stdin:
        line = raw.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError as e:
            print(
                json.dumps({"ok": False, "error": f"bad json: {e}"}, ensure_ascii=False),
                flush=True,
            )
            continue
        cmd = req.get("cmd")
        if cmd == "ping":
            print(json.dumps({"ok": True, "pong": True}, ensure_ascii=False), flush=True)
            continue
        if cmd == "quit":
            print(json.dumps({"ok": True, "bye": True}, ensure_ascii=False), flush=True)
            return 0
        if cmd != "transcribe":
            print(
                json.dumps({"ok": False, "error": f"unknown cmd: {cmd}"}, ensure_ascii=False),
                flush=True,
            )
            continue
        try:
            audio_path = Path(str(req["input"])).resolve()
            user_dir = Path(str(req["user_import_dir"])).resolve()
            score_id = str(req.get("id") or f"user_audio_{audio_path.stem}")[:48]
            title = str(req.get("title") or audio_path.stem)
            hop_sec = float(req.get("hop_sec", 0.4))
            max_sec = float(req.get("max_sec", 45.0))
            emphasize = bool(req.get("emphasize_piano", False))
            use_demucs = bool(req.get("demucs", False))
            out = run_transcribe_job(
                audio_path=audio_path,
                user_dir=user_dir,
                score_id=score_id,
                title=title,
                hop_sec=hop_sec,
                max_sec=max_sec,
                emphasize_piano=emphasize,
                use_demucs=use_demucs,
            )
            print(json.dumps(out, ensure_ascii=False), flush=True)
        except Exception as e:
            print(
                json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False),
                flush=True,
            )
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--serve",
        action="store_true",
        help="常驻：stdin JSON 任务，复用 ORT session（秒级二次导入）",
    )
    ap.add_argument("--input", type=Path, default=None)
    ap.add_argument("--title", default="")
    ap.add_argument("--id", default="")
    ap.add_argument("--user-import-dir", type=Path, default=None)
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
    ap.add_argument(
        "--demucs",
        action="store_true",
        help="可选：有 demucs 时先 --two-stems=vocals 取 no_vocals 再转录；无则跳过",
    )
    args = ap.parse_args()

    if args.serve:
        return serve()

    if args.input is None or args.user_import_dir is None:
        _log("需要 --input 与 --user-import-dir（或使用 --serve）")
        return 2

    audio_path = args.input.resolve()
    stem = "".join(c if c.isalnum() or c in "_-" else "_" for c in audio_path.stem.lower())
    score_id = (args.id.strip() or f"user_audio_{stem}")[:48]
    title = args.title.strip() or audio_path.stem
    out = run_transcribe_job(
        audio_path=audio_path,
        user_dir=args.user_import_dir.resolve(),
        score_id=score_id,
        title=title,
        hop_sec=args.hop_sec,
        max_sec=float(args.max_sec),
        emphasize_piano=bool(args.emphasize_piano),
        use_demucs=bool(args.demucs),
    )
    if not out.get("ok"):
        _log(out.get("error") or "失败")
        return int(out.get("code") or 1)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

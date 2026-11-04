"""Build synthetic practice_listen testdata (WAV + manifest JSONL)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

_SCRIPTS = Path(__file__).resolve().parents[1]
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

try:
    from .audio_io import read_wav_mono, synth_tone, write_wav_mono
except ImportError:
    from practice_listen_eval.audio_io import read_wav_mono, synth_tone, write_wav_mono

REPO = Path(__file__).resolve().parents[2]
OUT_DIR = REPO / "testdata" / "practice_listen"
SR = 22050


def _build_audio(plan: list[tuple[float, int, str]]) -> np.ndarray:
    duration_ms = max((p[0] for p in plan), default=500.0) + 800.0
    n = int(SR * duration_ms / 1000.0) + SR
    audio = np.zeros(n, dtype=np.float32)
    for onset_ms, midi, label in plan:
        if label == "miss":
            continue
        tone = synth_tone(midi, 0.35, SR, amplitude=0.35 if label != "extra" else 0.28)
        start = int(SR * onset_ms / 1000.0)
        end = min(n, start + len(tone))
        audio[start:end] += tone[: end - start]
    audio += np.random.default_rng(42).normal(0, 0.003, size=audio.shape).astype(np.float32)
    peak = float(np.max(np.abs(audio))) or 1.0
    return (audio / peak * 0.9).astype(np.float32)


def _seg(
    seg_id: str,
    score_id: str,
    wav_name: str,
    guide_audio: bool,
    plan: list[tuple[float, int, str]],
    chords: list[list[int]],
) -> dict:
    audio = _build_audio(plan)
    wav_rel = f"testdata/practice_listen/{wav_name}"
    write_wav_mono(OUT_DIR / wav_name, audio, SR)
    events = []
    for (onset_ms, midi, label), chord in zip(plan, chords):
        events.append(
            {
                "onset_ms": onset_ms,
                "midi": midi,
                "label": label,
                "chord": chord,
            }
        )
    return {
        "id": seg_id,
        "wav": wav_rel,
        "score_id": score_id,
        "guide_audio": guide_audio,
        "sample_rate": SR,
        "events": events,
        "waiting_chords": [
            {"t_ms": onset_ms, "midis": chord}
            for (onset_ms, _midi, _label), chord in zip(plan, chords)
        ],
        "notes": f"synthetic fixture for {score_id}",
    }


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    a = _seg(
        "seg_clean_hits",
        "fixture_cde",
        "seg_clean_hits.wav",
        False,
        [
            (200.0, 60, "hit"),
            (700.0, 62, "hit"),
            (1200.0, 64, "hit"),
        ],
        [[60], [62], [64]],
    )

    b_plan = [
        (200.0, 60, "hit"),
        (600.0, 61, "wrong"),
        (1000.0, 64, "miss"),
        (1400.0, 67, "extra"),
        (1800.0, 65, "hit"),
    ]
    b_chords = [[60], [62], [64], [65], [65]]
    b = _seg(
        "seg_wrong_miss_extra",
        "fixture_messy",
        "seg_wrong_miss_extra.wav",
        True,
        b_plan,
        b_chords,
    )

    # Soft guide bleed of expected notes (demo speaker) on messy segment.
    play, _ = read_wav_mono(OUT_DIR / "seg_wrong_miss_extra.wav")
    guide = np.zeros_like(play)
    for onset_ms, midi in [(180.0, 60), (580.0, 62), (980.0, 64), (1760.0, 65)]:
        tone = synth_tone(midi, 0.25, SR, amplitude=0.08)
        start = int(SR * onset_ms / 1000.0)
        end = min(len(guide), start + len(tone))
        guide[start:end] += tone[: end - start]
    mix = play + guide[: len(play)]
    peak = float(np.max(np.abs(mix))) or 1.0
    write_wav_mono(OUT_DIR / "seg_wrong_miss_extra.wav", (mix / peak * 0.9).astype(np.float32), SR)

    manifest = OUT_DIR / "manifest.jsonl"
    with manifest.open("w", encoding="utf-8") as f:
        for row in (a, b):
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    (OUT_DIR / "scores").mkdir(exist_ok=True)
    (OUT_DIR / "scores" / "fixture_cde.json").write_text(
        json.dumps({"notes": [{"midi": 60}, {"midi": 62}, {"midi": 64}]}),
        encoding="utf-8",
    )
    (OUT_DIR / "scores" / "fixture_messy.json").write_text(
        json.dumps({"notes": [{"midi": 60}, {"midi": 62}, {"midi": 64}, {"midi": 65}]}),
        encoding="utf-8",
    )
    print(f"Wrote {manifest} and WAVs under {OUT_DIR}")


if __name__ == "__main__":
    main()

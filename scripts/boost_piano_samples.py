#!/usr/bin/env python3
"""Convert MusyngKite MP3 one-shots to mono 22.05 kHz PCM WAV for cache-time gain.

Source peaks are only ~3–9% of full scale, so ScoreAudioPlayer applies
PracticeConstants.sampleGain (soft-clip) when copying into the temp cache.
This script only prepares linear PCM assets (no bake-in gain).

Usage (from repo root):
  python scripts/boost_piano_samples.py
"""

from __future__ import annotations

import array
import pathlib
import sys

import numpy as np

try:
    import miniaudio
except ImportError:
    print("miniaudio required: pip install miniaudio", file=sys.stderr)
    raise SystemExit(1)

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "piano"
TARGET_SR = 22050
MIDI_MIN, MIDI_MAX = 21, 108


def resample_mono(x: np.ndarray, src_rate: int, dst_rate: int) -> np.ndarray:
    if src_rate == dst_rate:
        return x.astype(np.float64, copy=False)
    duration = len(x) / src_rate
    n_out = max(1, int(round(duration * dst_rate)))
    t_src = np.linspace(0.0, 1.0, num=len(x), endpoint=False)
    t_dst = np.linspace(0.0, 1.0, num=n_out, endpoint=False)
    return np.interp(t_dst, t_src, x).astype(np.float64)


def convert_one(mp3_path: pathlib.Path) -> tuple[str, int]:
    decoded = miniaudio.decode_file(str(mp3_path))
    samples = np.frombuffer(decoded.samples, dtype=np.int16).astype(np.float64)
    if decoded.nchannels == 2:
        samples = samples.reshape(-1, 2).mean(axis=1)
    elif decoded.nchannels != 1:
        samples = samples.reshape(-1, decoded.nchannels).mean(axis=1)
    samples = samples / 32768.0
    mono = resample_mono(samples, decoded.sample_rate, TARGET_SR)
    pcm = np.clip(np.rint(mono * 32767.0), -32768, 32767).astype(np.int16)
    arr = array.array("h", pcm.tolist())
    sound = miniaudio.DecodedSoundFile(
        mp3_path.stem,
        1,
        TARGET_SR,
        miniaudio.SampleFormat.SIGNED16,
        arr,
    )
    wav_path = OUT / f"{mp3_path.stem}.wav"
    miniaudio.wav_write_file(str(wav_path), sound)
    return wav_path.name, wav_path.stat().st_size


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    mp3s = [OUT / f"n{m}.mp3" for m in range(MIDI_MIN, MIDI_MAX + 1)]
    missing = [p for p in mp3s if not p.exists()]
    if missing:
        print(f"missing {len(missing)} mp3 files; run download_piano_samples.py first", file=sys.stderr)
        return 1

    total = 0
    for mp3 in mp3s:
        name, size = convert_one(mp3)
        total += size
        print(f"{name}: {size}")

    # Remove MP3s after successful WAV write to avoid shipping quiet duplicates.
    for mp3 in mp3s:
        mp3.unlink(missing_ok=True)

    readme = OUT / "README.txt"
    readme.write_text(
        "Acoustic Grand Piano samples from MusyngKite via midi-js-soundfonts\n"
        "Source: https://gleitz.github.io/midi-js-soundfonts/"
        "MusyngKite/acoustic_grand_piano-mp3/\n"
        "License: see third_party/soundfonts/MIDI_JS_SOUNDFONTS_LICENSE.txt\n"
        "Mapped as n{midi}.wav (mono 22050 Hz PCM) for MIDI 21–108 (A0–C8).\n"
        "Peaks in the source MP3s are very low; ScoreAudioPlayer applies\n"
        "PracticeConstants.sampleGain with soft-clip when building the play cache.\n"
        "Regenerate: python scripts/download_piano_samples.py && "
        "python scripts/boost_piano_samples.py\n",
        encoding="utf-8",
    )
    print(f"done: {MIDI_MAX - MIDI_MIN + 1} wav files, {total / 1e6:.2f} MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

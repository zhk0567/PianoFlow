#!/usr/bin/env python3
"""Download Acoustic Grand Piano one-shots (MusyngKite) into assets/audio/piano."""

from __future__ import annotations

import concurrent.futures
import pathlib
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "piano"
BASE = (
    "https://gleitz.github.io/midi-js-soundfonts/"
    "MusyngKite/acoustic_grand_piano-mp3"
)
NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
MIDI_MIN, MIDI_MAX = 21, 108


def midi_to_name(midi: int) -> str:
    return f"{NAMES[midi % 12]}{(midi // 12) - 1}"


def fetch_one(midi: int) -> tuple[int, str]:
    name = midi_to_name(midi)
    url = f"{BASE}/{name}.mp3"
    dest = OUT / f"n{midi}.mp3"
    if dest.exists() and dest.stat().st_size > 1000:
        return midi, "skip"
    req = urllib.request.Request(url, headers={"User-Agent": "PianoFlow/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = resp.read()
    if len(data) < 500:
        raise RuntimeError(f"too small: {name} ({len(data)} bytes)")
    dest.write_bytes(data)
    return midi, f"ok {len(data)}"


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    midis = list(range(MIDI_MIN, MIDI_MAX + 1))
    ok = 0
    errors: list[str] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        futures = {pool.submit(fetch_one, m): m for m in midis}
        for fut in concurrent.futures.as_completed(futures):
            midi = futures[fut]
            try:
                m, status = fut.result()
                print(f"n{m}: {status}")
                ok += 1
            except Exception as exc:  # noqa: BLE001
                errors.append(f"n{midi}: {exc}")
                print(f"n{midi}: FAIL {exc}", file=sys.stderr)

    readme = OUT / "README.txt"
    readme.write_text(
        "Acoustic Grand Piano samples from MusyngKite via midi-js-soundfonts\n"
        f"Source: {BASE}/\n"
        "License: see third_party/soundfonts/MIDI_JS_SOUNDFONTS_LICENSE.txt\n"
        "Mapped as n{midi}.mp3 for MIDI 21–108 (A0–C8).\n"
        "After download, run: python scripts/boost_piano_samples.py\n"
        "to convert to mono 22050 Hz WAV (app applies sampleGain at cache time).\n",
        encoding="utf-8",
    )
    print(f"done: {ok}/{len(midis)}")
    if errors:
        print("errors:", *errors, sep="\n  ", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

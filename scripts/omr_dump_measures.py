#!/usr/bin/env python3
"""Dump first N measures RH/LH pitches from MusicXML for PDF side-by-side proofread.

Usage:
  python .\\scripts\\omr_dump_measures.py --id hisaishi_castle_in_the_sky --bars 8
  python .\\scripts\\omr_dump_measures.py --all-omr --bars 6
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

from musicxml_to_score import load_xml_root, local, parse_musicxml  # noqa: E402

CATALOG = REPO / "assets" / "scores" / "catalog.json"
MUSICXML = REPO / "assets" / "scores" / "musicxml"

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi_name(m: int) -> str:
    return f"{NOTE_NAMES[m % 12]}{m // 12 - 1}"


def omr_ids() -> list[str]:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    return [
        s["id"]
        for s in data.get("songs") or []
        if str(s.get("scoreKind") or "") == "omrDraft"
    ]


def find_xml(score_id: str) -> Path:
    for ext in (".musicxml", ".xml"):
        p = MUSICXML / f"{score_id}{ext}"
        if p.is_file():
            return p
    raise FileNotFoundError(score_id)


def measure_boundaries(root) -> list[float]:
    """Return cumulative beat starts for each measure (0-based), from divisions."""
    # Prefer parse_musicxml note starts grouped by measure index if available.
    # Fallback: scan measure elements with onset accumulation.
    onsets = [0.0]
    for part in root:
        if local(part.tag) != "part":
            continue
        beat = 0.0
        for meas in part:
            if local(meas.tag) != "measure":
                continue
            onsets.append(beat)  # start of this measure recorded after advance? fix below
        break
    # Rebuild properly
    starts: list[float] = []
    for part in root:
        if local(part.tag) != "part":
            continue
        beat = 0.0
        divisions = 1
        for meas in part:
            if local(meas.tag) != "measure":
                continue
            starts.append(beat)
            meas_len = 0.0
            for el in meas:
                tag = local(el.tag)
                if tag == "attributes":
                    for c in el:
                        if local(c.tag) == "divisions" and c.text:
                            divisions = int(c.text)
                elif tag == "note":
                    is_chord = any(local(c.tag) == "chord" for c in el)
                    is_grace = any(local(c.tag) == "grace" for c in el)
                    dur = 0
                    for c in el:
                        if local(c.tag) == "duration" and c.text:
                            dur = int(c.text)
                    if is_grace:
                        continue
                    if not is_chord:
                        meas_len += dur / float(divisions)
                elif tag == "backup":
                    for c in el:
                        if local(c.tag) == "duration" and c.text:
                            meas_len -= int(c.text) / float(divisions)
                elif tag == "forward":
                    for c in el:
                        if local(c.tag) == "duration" and c.text:
                            meas_len += int(c.text) / float(divisions)
            # Prefer measure time signature length if notes shorter
            if meas_len <= 0:
                meas_len = 4.0
            beat += meas_len
        break
    return starts


def dump(score_id: str, bars: int) -> str:
    xml_path = find_xml(score_id)
    root = load_xml_root(xml_path)
    score = parse_musicxml(root)
    notes = score["notes"]
    starts = measure_boundaries(root)
    lines = [
        f"# Measure dump — `{score_id}`",
        f"- XML: `{xml_path.relative_to(REPO)}`",
        f"- notes: {len(notes)} bpm={score.get('bpm')} key={score.get('keySignature')}",
        f"- dumping first {bars} measures",
        "",
    ]
    for mi in range(min(bars, max(0, len(starts)))):
        t0 = starts[mi]
        t1 = starts[mi + 1] if mi + 1 < len(starts) else t0 + 999
        bucket: dict[str, list] = {"right": [], "left": []}
        for n in notes:
            st = float(n["start"])
            if t0 - 1e-6 <= st < t1 - 1e-6:
                bucket[n["hand"]].append(n)
        lines.append(f"## Bar {mi + 1}  (beat {t0:.3f}–{t1:.3f})")
        for hand in ("right", "left"):
            seq = sorted(bucket[hand], key=lambda x: (x["start"], x["midi"]))
            if not seq:
                lines.append(f"- {hand}: (empty)")
                continue
            # group by start time
            by_t: dict[float, list[int]] = defaultdict(list)
            for n in seq:
                by_t[round(float(n["start"]), 4)].append(int(n["midi"]))
            parts = []
            for t in sorted(by_t):
                names = "+".join(midi_name(m) for m in sorted(by_t[t]))
                parts.append(f"{t:.2f}:{names}")
            lines.append(f"- {hand}: " + " | ".join(parts))
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id")
    ap.add_argument("--all-omr", action="store_true")
    ap.add_argument("--bars", type=int, default=8)
    ap.add_argument("--write", action="store_true", help="write docs/omr_audit/{id}_measures.md")
    args = ap.parse_args()
    ids = omr_ids() if args.all_omr else ([args.id] if args.id else [])
    if not ids:
        print("Provide --id or --all-omr", file=sys.stderr)
        return 2
    out_dir = REPO / "docs" / "omr_audit"
    out_dir.mkdir(parents=True, exist_ok=True)
    for sid in ids:
        text = dump(sid, args.bars)
        print(text)
        if args.write:
            p = out_dir / f"{sid}_measures.md"
            p.write_text(text + "\n", encoding="utf-8")
            print(f"WROTE {p.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

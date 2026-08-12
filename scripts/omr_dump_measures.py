# -*- coding: utf-8 -*-
"""Dump MusicXML measure pitches for OMR spot-check."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "scripts"))
from musicxml_to_score import load_xml_root, local  # noqa: E402


def measures(root):
    for part in root.iter():
        if local(part.tag) == "part":
            for m in part:
                if local(m.tag) == "measure":
                    yield m


def dump_measure(m) -> str:
    num = m.get("number", "?")
    rh, lh = [], []
    for n in m:
        if local(n.tag) != "note":
            continue
        staff = "1"
        for c in n:
            if local(c.tag) == "staff" and c.text:
                staff = c.text
        pitch = None
        for c in n:
            if local(c.tag) == "pitch":
                pitch = c
                break
        if pitch is None:
            lab = "R"
        else:
            step = alter = octv = ""
            for c in pitch:
                t = local(c.tag)
                if t == "step":
                    step = c.text or ""
                elif t == "alter":
                    alter = "#" if c.text == "1" else ("b" if c.text == "-1" else "")
                elif t == "octave":
                    octv = c.text or ""
            lab = f"{step}{alter}{octv}"
        (rh if staff == "1" else lh).append(lab)
    return f"m{num} RH={rh} LH={lh}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True)
    ap.add_argument("--from", dest="start", type=int, default=1)
    ap.add_argument("--to", dest="end", type=int, default=16)
    args = ap.parse_args()
    path = REPO / "assets" / "scores" / "musicxml" / f"{args.id}.musicxml"
    if not path.exists():
        path = REPO / "third_party" / "scores_musicxml" / f"{args.id}.musicxml"
    root = load_xml_root(path)
    for m in measures(root):
        try:
            num = int(m.get("number") or "0")
        except ValueError:
            continue
        if args.start <= num <= args.end:
            print(dump_measure(m))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

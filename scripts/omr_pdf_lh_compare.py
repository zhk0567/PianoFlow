# -*- coding: utf-8 -*-
"""Compare LH bass notes between PDF crop notes (manual) — thin restore stub."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "scripts"))
from omr_dump_measures import dump_measure, measures  # noqa: E402
from musicxml_to_score import load_xml_root  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Dump LH of MusicXML measures for PDF side-by-side compare"
    )
    ap.add_argument("--id", required=True)
    ap.add_argument("--from", dest="start", type=int, default=1)
    ap.add_argument("--to", dest="end", type=int, default=8)
    args = ap.parse_args()
    path = REPO / "assets" / "scores" / "musicxml" / f"{args.id}.musicxml"
    root = load_xml_root(path)
    print(f"[PianoFlow/omr] LH compare dump {args.id} m{args.start}-{args.end}")
    print("Open PDF crop alongside; mark mismatches manually.")
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

# -*- coding: utf-8 -*-
"""Pitch spot-check helper: dump RH of selected measures (manual PDF compare)."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "scripts"))
from omr_dump_measures import dump_measure, measures  # noqa: E402
from musicxml_to_score import load_xml_root  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True)
    ap.add_argument("--measures", default="1,2,3,4,5,6,7,8")
    args = ap.parse_args()
    want = {int(x.strip()) for x in args.measures.split(",") if x.strip()}
    path = REPO / "assets" / "scores" / "musicxml" / f"{args.id}.musicxml"
    root = load_xml_root(path)
    for m in measures(root):
        try:
            num = int(m.get("number") or "0")
        except ValueError:
            continue
        if num in want:
            print(dump_measure(m))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

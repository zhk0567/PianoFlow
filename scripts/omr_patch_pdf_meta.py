# -*- coding: utf-8 -*-
"""Patch / force PDF-derived tempo metadata helpers (thin restore)."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True)
    ap.add_argument("--bpm", type=int, required=True)
    args = ap.parse_args()
    for rel in (
        REPO / "assets" / "scores" / f"{args.id}.json",
        REPO / "assets" / "scores" / "catalog.json",
    ):
        if not rel.exists():
            continue
        data = json.loads(rel.read_text(encoding="utf-8"))
        if rel.name == "catalog.json":
            for s in data.get("songs") or []:
                if s.get("id") == args.id:
                    s["bpm"] = args.bpm
                    print(f"[PianoFlow/omr] catalog bpm={args.bpm} for {args.id}")
        else:
            data["bpm"] = args.bpm
            print(f"[PianoFlow/omr] json bpm={args.bpm} for {args.id}")
        rel.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

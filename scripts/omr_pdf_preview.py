#!/usr/bin/env python3
"""Render OMR reference PDF pages to docs/omr_audit/{id}_pN.png for visual proofread.

Usage (PowerShell, repo root):
  python .\\scripts\\omr_pdf_preview.py --id hisaishi_castle_in_the_sky
  python .\\scripts\\omr_pdf_preview.py --all-omr --pages 2 --dpi 160
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import fitz  # PyMuPDF

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "assets" / "scores" / "catalog.json"
PDF_DIR = REPO / "third_party" / "scores_pdf"
OUT_DIR = REPO / "docs" / "omr_audit"


def omr_ids() -> list[str]:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    return [
        s["id"]
        for s in data.get("songs") or []
        if str(s.get("scoreKind") or "") == "omrDraft"
    ]


def render(score_id: str, pages: int, dpi: int) -> list[Path]:
    pdf = PDF_DIR / f"{score_id}.pdf"
    if not pdf.is_file():
        raise FileNotFoundError(pdf)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    doc = fitz.open(pdf)
    zoom = dpi / 72.0
    mat = fitz.Matrix(zoom, zoom)
    written: list[Path] = []
    n = min(pages, doc.page_count)
    for i in range(n):
        pix = doc.load_page(i).get_pixmap(matrix=mat, alpha=False)
        out = OUT_DIR / f"{score_id}_p{i + 1}.png"
        pix.save(out.as_posix())
        written.append(out)
        print(f"OK {score_id} page {i + 1}/{doc.page_count} -> {out.relative_to(REPO)}")
    doc.close()
    return written


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", help="single score id")
    ap.add_argument("--all-omr", action="store_true")
    ap.add_argument("--pages", type=int, default=2)
    ap.add_argument("--dpi", type=int, default=160)
    args = ap.parse_args()
    ids = omr_ids() if args.all_omr else ([args.id] if args.id else [])
    if not ids:
        print("Provide --id or --all-omr", file=sys.stderr)
        return 2
    for sid in ids:
        try:
            render(sid, args.pages, args.dpi)
        except Exception as e:
            print(f"FAIL {sid}: {e}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# -*- coding: utf-8 -*-
"""Render PDF pages to PNG for OMR visual proofreading."""
from __future__ import annotations

import argparse
from pathlib import Path

import fitz
from PIL import Image
from io import BytesIO


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True, help="Score id (PDF stem under third_party/scores_pdf)")
    ap.add_argument("--dpi", type=int, default=200)
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--pages", default="all", help="e.g. 1-2 or all")
    args = ap.parse_args()
    repo = Path(__file__).resolve().parents[1]
    pdf = repo / "third_party" / "scores_pdf" / f"{args.id}.pdf"
    if not pdf.exists():
        raise SystemExit(f"missing {pdf}")
    out = args.out or (repo / "docs" / "omr_audit" / "_pdf_preview" / args.id)
    out.mkdir(parents=True, exist_ok=True)
    doc = fitz.open(pdf)
    if args.pages == "all":
        pages = range(len(doc))
    else:
        a, b = args.pages.split("-", 1)
        pages = range(int(a) - 1, int(b))
    mat = fitz.Matrix(args.dpi / 72, args.dpi / 72)
    for i in pages:
        if i < 0 or i >= len(doc):
            continue
        pix = doc[i].get_pixmap(matrix=mat)
        im = Image.open(BytesIO(pix.tobytes("png")))
        dest = out / f"p{i + 1}.png"
        im.save(dest)
        print(f"[PianoFlow/omr] wrote {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

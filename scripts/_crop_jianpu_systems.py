# -*- coding: utf-8 -*-
"""Crop high-res jianpu systems for proofreading."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "docs" / "omr_audit" / "_jianpu_proof"


def crop_systems(sid: str, page: int, merge_gap: int = 80, pad: int = 20) -> None:
    hi = ROOT / sid / f"hi_p{page}.png"
    im = Image.open(hi).convert("L")
    arr = np.asarray(im)
    ink = (arr < 200).mean(axis=1)
    sm = np.convolve(ink, np.ones(15) / 15, mode="same")
    thr = max(0.012, sm.mean() * 0.5)
    active = sm > thr
    runs = []
    start = None
    for i, a in enumerate(active):
        if a and start is None:
            start = i
        elif not a and start is not None:
            if i - start > 50:
                runs.append((start, i))
            start = None
    if start is not None:
        runs.append((start, len(active)))
    merged: list[list[int]] = []
    for s, e in runs:
        if not merged:
            merged.append([s, e])
            continue
        if s - merged[-1][1] < merge_gap:
            merged[-1][1] = e
        else:
            merged.append([s, e])
    out = ROOT / sid / "_sys"
    out.mkdir(exist_ok=True)
    rgb = Image.open(hi)
    print(sid, f"p{page}", "runs", len(runs), "systems", len(merged))
    for i, (s, e) in enumerate(merged, 1):
        y0 = max(0, s - pad)
        y1 = min(rgb.height, e + pad)
        crop = rgb.crop((0, y0, rgb.width, y1))
        p = out / f"p{page}_s{i:02d}.png"
        crop.save(p)
        print(" ", p.name, crop.size)


def main() -> None:
    for sid, pages, gap in [
        ("when_you_wish_upon_a_star", [1, 2], 100),
        ("pure_imagination", [1, 2], 90),
        ("an_he_qiao", [1, 2], 70),
    ]:
        for pg in pages:
            crop_systems(sid, pg, merge_gap=gap)


if __name__ == "__main__":
    main()

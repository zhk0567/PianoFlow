#!/usr/bin/env python3
"""Estimate LH/RH pitches from PDF page raster by staff-line + notehead detection.

Crude OMR-from-render for proofreading (not a full OMR). Outputs markdown
comparing estimated PDF pitches vs MusicXML parse for opening bars.

Usage:
  python .\\scripts\\omr_pdf_pitch_spotcheck.py --id hisaishi_castle_in_the_sky --bars 8
"""

from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from pathlib import Path

import fitz
import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))
from musicxml_to_score import load_xml_root, parse_musicxml  # noqa: E402

NOTE = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi_name(m: int) -> str:
    return f"{NOTE[m % 12]}{m // 12 - 1}"


def load_page_gray(pdf: Path, page_i: int, dpi: int = 200) -> np.ndarray:
    doc = fitz.open(pdf)
    page = doc[page_i]
    pix = page.get_pixmap(matrix=fitz.Matrix(dpi / 72, dpi / 72), alpha=False)
    img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, 3)
    doc.close()
    return img.mean(axis=2)


def find_staff_systems(gray: np.ndarray) -> list[tuple[int, int]]:
    """Return (y0,y1) bands that look like grand-staff systems via horizontal ink."""
    ink = (gray < 200).astype(np.float32)
    row = ink.mean(axis=1)
    # smooth
    k = 7
    ker = np.ones(k) / k
    sm = np.convolve(row, ker, mode="same")
    thr = max(0.015, float(sm.mean() + 0.25 * sm.std()))
    active = sm > thr
    bands: list[tuple[int, int]] = []
    i = 0
    h = len(active)
    while i < h:
        if not active[i]:
            i += 1
            continue
        j = i
        while j < h and active[j]:
            j += 1
        if j - i > 24:
            bands.append((i, j))
        i = j
    # merge close bands (treble+bass of one system)
    merged: list[tuple[int, int]] = []
    for y0, y1 in bands:
        if not merged:
            merged.append((y0, y1))
            continue
        py0, py1 = merged[-1]
        if y0 - py1 < 100:
            merged[-1] = (py0, y1)
        else:
            merged.append((y0, y1))
    return merged


def staff_line_ys(band: np.ndarray) -> list[int]:
    ink = (band < 180).mean(axis=1)
    # peak pick
    ys = []
    for y in range(2, len(ink) - 2):
        if ink[y] > 0.15 and ink[y] >= ink[y - 1] and ink[y] >= ink[y + 1]:
            if not ys or y - ys[-1] > 3:
                ys.append(y)
            elif ink[y] > ink[ys[-1]]:
                ys[-1] = y
    # keep densest 10 (two staves × 5)
    if len(ys) > 10:
        # cluster into two groups
        gaps = [(ys[i + 1] - ys[i], i) for i in range(len(ys) - 1)]
        gaps.sort(reverse=True)
        # take contiguous runs of 5
    # heuristic: pick 5 consecutive with similar spacing for treble, then bass
    best = []
    for i in range(len(ys) - 4):
        chunk = ys[i : i + 5]
        sp = [chunk[j + 1] - chunk[j] for j in range(4)]
        if max(sp) - min(sp) <= 3 and 4 <= float(np.mean(sp)) <= 18:
            best.append(chunk)
    return best[:2]  # treble, bass line lists


def pitch_from_y(y: float, lines: list[int], clef: str) -> int | None:
    if len(lines) != 5:
        return None
    space = float(np.mean([lines[i + 1] - lines[i] for i in range(4)]))
    # line 0 = top line
    # treble: top line = F5 (midi 77), each step down = -1 diatonic ≈ -1 or -2 semitone
    # Use diatonic steps from top line
    steps_from_top = (lines[0] - y) / (space / 2.0)  # negative if below top
    # round to nearest half-space (line or space)
    half = int(round(steps_from_top))
    # Treble top line F5; going down: E5 D5 C5 B4 A4 G4 F4 E4 D4 C4...
    # Bass top line A3; ...
    diatonic = ["C", "D", "E", "F", "G", "A", "B"]
    if clef == "G":
        # F5 index
        start_name, start_oct = "F", 5
    else:
        start_name, start_oct = "A", 3
    idx = diatonic.index(start_name)
    # half steps of staff: each half-space is one diatonic step DOWN when y increases
    # steps_from_top positive means above top line
    diatonic_steps = -half  # down the staff
    idx2 = idx + diatonic_steps
    octv = start_oct
    while idx2 < 0:
        idx2 += 7
        octv -= 1
    while idx2 >= 7:
        idx2 -= 7
        octv += 1
    name = diatonic[idx2]
    # midi
    base = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}[name]
    return (octv + 1) * 12 + base


def detect_noteheads(band: np.ndarray) -> list[tuple[int, int]]:
    """Return (x,y) centers of dark blobs that look like noteheads."""
    ink = band < 140
    # remove long horizontal lines roughly
    row_frac = ink.mean(axis=1)
    for y in range(len(row_frac)):
        if row_frac[y] > 0.35:
            ink[y, :] = False
    ys, xs = np.where(ink)
    if len(xs) == 0:
        return []
    # grid cluster
    visited = set()
    heads = []
    ink_set = set(zip(ys.tolist(), xs.tolist()))
    for y, x in zip(ys.tolist(), xs.tolist()):
        if (y, x) in visited:
            continue
        # flood small
        stack = [(y, x)]
        visited.add((y, x))
        cells = []
        while stack:
            cy, cx = stack.pop()
            cells.append((cy, cx))
            for dy in (-2, -1, 0, 1, 2):
                for dx in (-2, -1, 0, 1, 2):
                    ny, nx = cy + dy, cx + dx
                    if (ny, nx) in ink_set and (ny, nx) not in visited:
                        visited.add((ny, nx))
                        stack.append((ny, nx))
        if 8 <= len(cells) <= 120:
            cy = int(np.mean([c[0] for c in cells]))
            cx = int(np.mean([c[1] for c in cells]))
            heads.append((cx, cy))
    heads.sort()
    return heads


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True)
    ap.add_argument("--page", type=int, default=0)
    ap.add_argument("--system", type=int, default=0)
    args = ap.parse_args()
    pdf = REPO / "third_party" / "scores_pdf" / f"{args.id}.pdf"
    gray = load_page_gray(pdf, args.page)
    systems = find_staff_systems(gray)
    print(f"systems on page {args.page}: {len(systems)}")
    if not systems:
        return 1
    si = min(args.system, len(systems) - 1)
    y0, y1 = systems[si]
    band = gray[y0:y1, :]
    staves = staff_line_ys(band)
    print(f"system {si} y={y0}-{y1} staves_found={len(staves)}")
    for i, lines in enumerate(staves):
        print(f"  staff{i} lines={lines} spacing≈{np.mean(np.diff(lines)):.1f}")
    heads = detect_noteheads(band)
    print(f"notehead candidates: {len(heads)}")
    # assign to nearest staff
    if len(staves) >= 2:
        treble, bass = staves[0], staves[1]
        mid = (treble[-1] + bass[0]) / 2
        rh, lh = [], []
        for x, y in heads:
            if y < mid:
                p = pitch_from_y(y, treble, "G")
                if p:
                    rh.append((x, midi_name(p), p))
            else:
                p = pitch_from_y(y, bass, "F")
                if p:
                    lh.append((x, midi_name(p), p))
        print("RH approx (x-sorted):", " ".join(n for _, n, _ in sorted(rh)[:40]))
        print("LH approx (x-sorted):", " ".join(n for _, n, _ in sorted(lh)[:40]))
    # MusicXML opening
    root = load_xml_root(REPO / "assets" / "scores" / "musicxml" / f"{args.id}.musicxml")
    score = parse_musicxml(root)
    notes = sorted(score["notes"], key=lambda n: (n["start"], n["midi"]))
    print("XML first 20:")
    for n in notes[:20]:
        print(f"  {n['start']:6.2f} {n['hand'][0]} {midi_name(int(n['midi']))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

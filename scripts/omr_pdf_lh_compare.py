#!/usr/bin/env python3
"""Compare PDF bass whole-notes vs MusicXML LH for OMR proofread.

Optimized for simple LH (one whole note / measure) like 天空之城.
Uses staff-line geometry from the PDF raster.

Usage:
  python .\\scripts\\omr_pdf_lh_compare.py --id hisaishi_castle_in_the_sky
  python .\\scripts\\omr_pdf_lh_compare.py --id hisaishi_castle_in_the_sky --fail-under 0.85
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

import fitz
import numpy as np

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))
from musicxml_to_score import load_xml_root, parse_musicxml  # noqa: E402

NOTE = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi_name(m: int) -> str:
    return f"{NOTE[m % 12]}{m // 12 - 1}"


def page_gray(pdf: Path, page_i: int, dpi: int) -> np.ndarray:
    doc = fitz.open(pdf)
    page = doc[page_i]
    pix = page.get_pixmap(matrix=fitz.Matrix(dpi / 72, dpi / 72), alpha=False)
    arr = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, 3)
    doc.close()
    return arr.mean(axis=2)


def find_staves5(gray: np.ndarray) -> list[list[int]]:
    ink = (gray < 160).astype(np.float32)
    row = ink.mean(axis=1)
    peaks: list[int] = []
    for y in range(2, len(row) - 2):
        if row[y] > 0.12 and row[y] >= row[y - 1] and row[y] >= row[y + 1]:
            if not peaks or y - peaks[-1] > 3:
                peaks.append(y)
            elif row[y] > row[peaks[-1]]:
                peaks[-1] = y
    staves: list[list[int]] = []
    i = 0
    while i + 4 < len(peaks):
        chunk = peaks[i : i + 5]
        sp = np.diff(chunk)
        if sp.min() >= 3 and sp.max() <= 16 and (sp.max() - sp.min()) <= 5:
            staves.append(list(chunk))
            i += 5
        else:
            i += 1
    return staves


def bass_midi_from_y(y: float, lines: list[int]) -> int:
    """Bass clef: bottom line = G2 (midi 43). lines[0]=top=A3, lines[4]=bottom=G2."""
    space = float(np.mean(np.diff(lines)))
    # half-spaces below top line
    half = int(round((y - lines[0]) / (space / 2.0)))
    # top line A3; each half-space down = one diatonic step
    diatonic = ["C", "D", "E", "F", "G", "A", "B"]
    idx = diatonic.index("A")
    octv = 3
    for _ in range(half):
        idx -= 1
        if idx < 0:
            idx = 6
            octv -= 1
    base = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}[diatonic[idx]]
    return (octv + 1) * 12 + base


def detect_heads_in_band(gray: np.ndarray, y0: int, y1: int, x0: int, x1: int) -> list[tuple[int, int]]:
    band = gray[y0:y1, x0:x1]
    ink = band < 130
    # kill staff lines
    rf = ink.mean(axis=1)
    for yy in range(len(rf)):
        if rf[yy] > 0.40:
            ink[yy, :] = False
    ys, xs = np.where(ink)
    if len(xs) == 0:
        return []
    ink_set = set(zip(ys.tolist(), xs.tolist()))
    visited: set[tuple[int, int]] = set()
    heads: list[tuple[int, int]] = []
    for y, x in zip(ys.tolist(), xs.tolist()):
        if (y, x) in visited:
            continue
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
        if 10 <= len(cells) <= 160:
            cy = int(np.mean([c[0] for c in cells])) + y0
            cx = int(np.mean([c[1] for c in cells])) + x0
            heads.append((cx, cy))
    heads.sort()
    return heads


def xml_lh_by_measure(score_id: str, pickup_beats: float = 1.0) -> dict[int, list[int]]:
    root = load_xml_root(REPO / "assets" / "scores" / "musicxml" / f"{score_id}.musicxml")
    score = parse_musicxml(root)
    bars: dict[int, list[int]] = defaultdict(list)
    for n in score["notes"]:
        if n["hand"] != "left":
            continue
        t = float(n["start"])
        if t < pickup_beats - 1e-6:
            b = 0
        else:
            b = int((t - pickup_beats) // 4) + 1
        bars[b].append(int(n["midi"]))
    return {k: sorted(v) for k, v in bars.items()}


def estimate_pdf_lh(pdf: Path, dpi: int = 220) -> list[tuple[int, int]]:
    """Return list of (measure_index_1based_approx, midi) for LH heads left-to-right across pages."""
    doc = fitz.open(pdf)
    out: list[tuple[int, int]] = []
    meas_i = 1
    for pi in range(doc.page_count):
        gray = page_gray(pdf, pi, dpi)
        staves = find_staves5(gray)
        # pair treble/bass
        systems = []
        for i in range(0, len(staves) - 1, 2):
            systems.append((staves[i], staves[i + 1]))
        w = gray.shape[1]
        for treble, bass in systems:
            y0 = max(0, bass[0] - int(0.5 * (bass[1] - bass[0])))
            y1 = min(gray.shape[0], bass[4] + int(2.2 * (bass[1] - bass[0])))
            # split system into ~6 measure slots
            # skip left margin for clef
            x_left = int(w * 0.12)
            x_right = int(w * 0.96)
            slots = 6
            for s in range(slots):
                x0 = x_left + int((x_right - x_left) * s / slots)
                x1 = x_left + int((x_right - x_left) * (s + 1) / slots)
                heads = detect_heads_in_band(gray, y0, y1, x0, x1)
                if not heads:
                    continue
                # pick darkest/central head (first by x)
                cx, cy = heads[0]
                midi = bass_midi_from_y(cy, bass)
                out.append((meas_i, midi))
                meas_i += 1
    doc.close()
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True)
    ap.add_argument("--dpi", type=int, default=220)
    ap.add_argument("--pickup", type=float, default=1.0)
    ap.add_argument("--fail-under", type=float, default=0.0)
    ap.add_argument("--max-bars", type=int, default=30)
    args = ap.parse_args()

    pdf = REPO / "third_party" / "scores_pdf" / f"{args.id}.pdf"
    xml_lh = xml_lh_by_measure(args.id, args.pickup)
    pdf_lh = estimate_pdf_lh(pdf, args.dpi)

    print(f"PDF LH detections: {len(pdf_lh)}")
    print(f"XML LH measures with notes: {len([k for k in xml_lh if k > 0])}")

    matches = 0
    compared = 0
    lines = []
    for i, (pm, pdf_midi) in enumerate(pdf_lh[: args.max_bars]):
        # map sequential detection index to XML measure i+1 (skip pickup 0)
        xm = i + 1
        xml_notes = xml_lh.get(xm) or []
        # compare to lowest LH (bass root)
        xml_root = min(xml_notes) if xml_notes else None
        ok = xml_root is not None and abs(xml_root - pdf_midi) <= 1  # allow ±1 staff err
        if xml_root is not None:
            compared += 1
            if ok:
                matches += 1
        flag = "OK" if ok else "DIFF"
        lines.append(
            f"m{xm}: PDF≈{midi_name(pdf_midi)}({pdf_midi})  XML={([midi_name(x) for x in xml_notes], xml_root)}  {flag}"
        )
        print(lines[-1])

    ratio = (matches / compared) if compared else 0.0
    print(f"MATCH {matches}/{compared} = {ratio:.1%}")
    out = REPO / "docs" / "omr_audit" / f"{args.id}_lh_compare.md"
    out.write_text(
        f"# LH compare `{args.id}`\n\n"
        f"Match: **{matches}/{compared} ({ratio:.1%})** (tolerance ±1 semitone)\n\n"
        + "\n".join(f"- {x}" for x in lines)
        + "\n",
        encoding="utf-8",
    )
    print(f"WROTE {out.relative_to(REPO)}")
    if args.fail_under and ratio < args.fail_under:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

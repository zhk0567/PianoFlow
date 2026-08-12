"""Render hi-res Castle m19-24 / m40-48 crops + dump MusicXML (no pitch rewrite)."""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from io import BytesIO
from pathlib import Path

import fitz
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "omr_audit" / "_castle_sop"
PDF = ROOT / "third_party" / "scores_pdf" / "hisaishi_castle_in_the_sky.pdf"
XML = ROOT / "assets" / "scores" / "musicxml" / "hisaishi_castle_in_the_sky.musicxml"


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def dump_bars(lo: int, hi: int) -> str:
    root = ET.parse(XML).getroot()
    lines: list[str] = []
    for part in root.iter():
        if local(part.tag) != "part":
            continue
        for measure in part:
            if local(measure.tag) != "measure":
                continue
            n = int(measure.get("number"))
            if n < lo or n > hi:
                continue
            rh, lh = [], []
            hand = "rh"
            for el in measure:
                t = local(el.tag)
                if t == "backup":
                    hand = "lh"
                    continue
                if t != "note":
                    continue
                rest = any(local(c.tag) == "rest" for c in el)
                pitch = "rest" if rest else None
                dur = typ = None
                for c in el:
                    ct = local(c.tag)
                    if ct == "pitch":
                        step = alter = octave = None
                        for p2 in c:
                            pt = local(p2.tag)
                            if pt == "step":
                                step = p2.text
                            elif pt == "alter":
                                alter = p2.text
                            elif pt == "octave":
                                octave = p2.text
                        acc = "#" if alter == "1" else "b" if alter == "-1" else ""
                        pitch = f"{step}{acc}{octave}"
                    elif ct == "duration":
                        dur = c.text
                    elif ct == "type":
                        typ = c.text
                item = f"{pitch}:{typ}({dur})"
                (rh if hand == "rh" else lh).append(item)
            lines.append(f"m{n} RH[{' '.join(rh)}] LH[{' '.join(lh)}]")
    return "\n".join(lines)


def render_page_crops() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    doc = fitz.open(PDF)
    mat = fitz.Matrix(400 / 72, 400 / 72)
    for pi in range(len(doc)):
        pix = doc[pi].get_pixmap(matrix=mat)
        im = Image.open(BytesIO(pix.tobytes("png")))
        dest = OUT / f"p{pi + 1}_400.png"
        im.save(dest)
        print(f"[PianoFlow/omr] wrote {dest} {im.size}")

    # Re-export known good system crops from p1_300 if present
    p300 = OUT / "p1_300.png"
    sys4 = OUT / "p1_sys4.png"
    if p300.exists() and sys4.exists():
        # copy labeled strip for m21-24 focus: use existing sys4
        im = Image.open(sys4).convert("RGB")
        w, h = im.size
        left = int(0.10 * w)
        usable = w - left - 5
        for i, m in enumerate(range(19, 25)):
            x0 = left + int(i * usable / 6)
            x1 = left + int((i + 1) * usable / 6)
            bar = im.crop((max(0, x0 - 4), 0, min(w, x1 + 4), h))
            d = ImageDraw.Draw(bar)
            d.rectangle([2, 2, 70, 26], fill="yellow")
            d.text((6, 6), f"m{m}", fill="black")
            dest = OUT / f"proof_m{m}.png"
            bar.save(dest)
            print(f"[PianoFlow/omr] wrote {dest}")


def main() -> None:
    render_page_crops()
    text = dump_bars(19, 30) + "\n\n" + dump_bars(40, 49)
    dest = OUT / "_dump_m19_30_and_m40_49.txt"
    dest.write_text(text + "\n", encoding="utf-8")
    print(f"[PianoFlow/omr] wrote {dest}")
    print(text)
    print(
        "[PianoFlow/omr] m21-24 / m40-48: multi-source pitch reads disagree — "
        "NO rewrite; still omrDraft"
    )


if __name__ == "__main__":
    main()

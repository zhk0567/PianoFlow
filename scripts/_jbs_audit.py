"""Compare 诀别书 PDF noteheads to MusicXML staff positions.

Prints one line per measure: OK or a position diff. Calibrate on page 1
(m1–8 already signed) before trusting later pages.
"""
from __future__ import annotations

import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path

import fitz
from PIL import Image

REPO = Path(r"F:\commercial\PianoFlow")
XML = REPO / "assets/scores/musicxml/jue_bie_shu.musicxml"
PDF = REPO / "third_party/scores_pdf/jue_bie_shu.pdf"
STEPS = "CDEFGAB"


def dia(step: str, octave: int) -> int:
    return octave * 7 + STEPS.index(step)


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def parse_xml():
    root = ET.parse(XML).getroot()
    part = next(el for el in root if local(el.tag) == "part")
    clef = {1: "G", 2: "F"}
    octave_shift = {1: 0, 2: 0}  # sounding = written + shift (in octaves)
    measures = []
    for m in part:
        if local(m.tag) != "measure":
            continue
        num = int(m.get("number"))
        new_system = False
        positions = {1: [], 2: []}  # staff -> list of diatonic positions (written)
        for el in m:
            t = local(el.tag)
            if t == "print" and (el.get("new-system") == "yes" or el.get("new-page") == "yes"):
                new_system = True
            elif t == "attributes":
                for c in el:
                    if local(c.tag) == "clef":
                        staff = int(c.get("number") or "1")
                        sign = next(x.text for x in c if local(x.tag) == "sign")
                        clef[staff] = sign
            elif t == "direction":
                for o in el.iter():
                    if local(o.tag) != "octave-shift":
                        continue
                    # direction may carry staff
                    staff = 1
                    for d in el:
                        if local(d.tag) == "staff" and d.text:
                            staff = int(d.text)
                    kind = o.get("type")
                    size = int(o.get("size") or "8")
                    octs = 1 if size == 8 else 2
                    if kind == "down":
                        # 8va: the staff prints an octave below the sounding pitch.
                        octave_shift[staff] = octs
                    elif kind == "up":
                        octave_shift[staff] = -octs
                    elif kind == "stop":
                        octave_shift[staff] = 0
            elif t == "note":
                staff_el = next((c for c in el if local(c.tag) == "staff"), None)
                staff = int(staff_el.text) if staff_el is not None and staff_el.text else 1
                if any(local(c.tag) == "rest" for c in el):
                    continue
                pitch = next(c for c in el if local(c.tag) == "pitch")
                step = next(c.text for c in pitch if local(c.tag) == "step")
                octave = int(next(c.text for c in pitch if local(c.tag) == "octave"))
                sounding = dia(step, octave)
                written = sounding - 7 * octave_shift[staff]
                bottom = 30 if clef[staff] == "G" else 18  # E4 or G2
                positions[staff].append(written - bottom)
        measures.append(
            {
                "n": num,
                "new": new_system or num == 1,
                "pos": positions,
                "clef": dict(clef),
            }
        )
    # clef recorded above is the clef AFTER the measure. Recompute clef-at-note
    # properly by doing it inside the loop — already applied before notes if
    # clef is in attributes at the start. A clef AFTER notes affects later
    # measures only, and we applied it before scanning notes if it appears
    # first. If clef is at the end, we wrongly used it for this measure's notes.
    return measures


def parse_xml_ordered():
    """Clef changes apply only to notes that follow them."""
    root = ET.parse(XML).getroot()
    part = next(el for el in root if local(el.tag) == "part")
    clef = {1: "G", 2: "F"}
    octave_shift = {1: 0, 2: 0}
    measures = []
    for m in part:
        if local(m.tag) != "measure":
            continue
        num = int(m.get("number"))
        new_system = num == 1
        positions = {1: [], 2: []}
        kinds = {1: [], 2: []}
        for el in m:
            t = local(el.tag)
            if t == "print" and (el.get("new-system") == "yes" or el.get("new-page") == "yes"):
                new_system = True
            elif t == "attributes":
                for c in el:
                    if local(c.tag) == "clef":
                        staff = int(c.get("number") or "1")
                        sign = next(x.text for x in c if local(x.tag) == "sign")
                        clef[staff] = sign
            elif t == "direction":
                for o in el.iter():
                    if local(o.tag) != "octave-shift":
                        continue
                    staff = 1
                    for d in el:
                        if local(d.tag) == "staff" and d.text:
                            staff = int(d.text)
                    kind = o.get("type")
                    size = int(o.get("size") or "8")
                    octs = 1 if size == 8 else 2
                    if kind == "down":
                        # 8va: the staff prints an octave below the sounding pitch.
                        octave_shift[staff] = octs
                    elif kind == "up":
                        octave_shift[staff] = -octs
                    elif kind == "stop":
                        octave_shift[staff] = 0
            elif t == "note":
                staff_el = next((c for c in el if local(c.tag) == "staff"), None)
                staff = int(staff_el.text) if staff_el is not None and staff_el.text else 1
                if any(local(c.tag) == "rest" for c in el):
                    continue
                pitch = next((c for c in el if local(c.tag) == "pitch"), None)
                if pitch is None:
                    continue
                step = next(c.text for c in pitch if local(c.tag) == "step")
                octave = int(next(c.text for c in pitch if local(c.tag) == "octave"))
                written = dia(step, octave) - 7 * octave_shift[staff]
                bottom = 30 if clef[staff] == "G" else 18
                kind_el = next((c for c in el if local(c.tag) == "type"), None)
                positions[staff].append(written - bottom)
                kinds[staff].append(kind_el.text if kind_el is not None and kind_el.text else "?")
        measures.append(
            {"n": num, "new": new_system, "pos": positions, "kind": kinds, "clef": dict(clef)}
        )
    systems = []
    cur = []
    for m in measures:
        if m["new"] and cur:
            systems.append(cur)
            cur = []
        cur.append(m)
    if cur:
        systems.append(cur)
    return systems


def render_page(page_i: int, zoom: float = 3.0):
    doc = fitz.open(PDF)
    page = doc[page_i]
    pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
    im = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
    return im, zoom, page.rect.height


def find_systems(im: Image.Image):
    w, h = im.size
    px = im.load()

    def lum(x, y):
        r, g, b = px[x, y]
        return (r + g + b) / 3

    line_rows = []
    x0, x1 = int(w * 0.12), int(w * 0.92)
    for y in range(int(h * 0.06), int(h * 0.97)):
        dark = n = 0
        for x in range(x0, x1, 3):
            n += 1
            if lum(x, y) < 150:
                dark += 1
        if n and dark / n > 0.28:
            line_rows.append(y)
    lines = []
    if line_rows:
        s = prev = line_rows[0]
        for y in line_rows[1:]:
            if y - prev <= 3:
                prev = y
            else:
                lines.append((s + prev) // 2)
                s = prev = y
        lines.append((s + prev) // 2)
    staves = []
    cur = []
    for i, y in enumerate(lines):
        if not cur:
            cur = [y]
            continue
        if y - cur[-1] <= 22:
            cur.append(y)
        else:
            if len(cur) >= 4:
                staves.append(cur[:5])
            cur = [y]
    if len(cur) >= 4:
        staves.append(cur[:5])
    systems = []
    i = 0
    while i < len(staves):
        if i + 1 < len(staves) and staves[i + 1][0] - staves[i][-1] < 160:
            systems.append((staves[i], staves[i + 1]))
            i += 2
        else:
            i += 1
    return systems, lum


def _absorb(blobs, x, y, step):
    for b in blobs:
        if abs(b[0] - x) < step * 1.35 and abs(b[1] - y) < step * 1.1:
            b[0] = (b[0] * b[2] + x) / (b[2] + 1)
            b[1] = (b[1] * b[2] + y) / (b[2] + 1)
            b[2] += 1
            return
    blobs.append([x, y, 1.0])


def noteheads(im, lum, staff, x0, x1, pad_up=10, pad_down=4):
    """Filled noteheads as staff positions (0 = bottom line).

    Hollow whole/half notes are invisible to this pass on purpose: a looser
    ring detector also latches onto ties and staff-line gaps.
    """
    if len(staff) < 5:
        return []
    bottom = staff[-1]
    top = staff[0]
    line_gap = (bottom - top) / 4.0
    step = line_gap / 2.0
    if step < 2:
        return []
    y_lo = int(top - step * pad_up)
    y_hi = int(bottom + step * pad_down)
    h = im.size[1]
    y_lo = max(0, y_lo)
    y_hi = min(h - 1, y_hi)
    blobs = []
    for x in range(x0, x1):
        run = 0
        run_y = 0
        for y in range(y_lo, y_hi):
            if lum(x, y) < 50:
                if run == 0:
                    run_y = y
                run += 1
            else:
                if step * 0.7 <= run <= step * 2.4:
                    _absorb(blobs, x, run_y + run / 2, step)
                run = 0
        if step * 0.7 <= run <= step * 2.4:
            _absorb(blobs, x, run_y + run / 2, step)
    out = []
    for b in blobs:
        if b[2] < 3:
            continue
        pos = round((bottom - b[1]) / step)
        out.append((b[0], pos))
    out.sort()
    return out


def bar_candidates(lum, treble, bass, w):
    y0, y1 = treble[0] + 2, bass[-1] - 2
    scores = []
    for x in range(int(w * 0.04), int(w * 0.99)):
        dark = n = 0
        for y in range(y0, y1, 2):
            n += 1
            if lum(x, y) < 120:
                dark += 1
        frac = dark / n if n else 0
        if frac > 0.48:
            scores.append((x, frac))
    clusters = []
    if scores:
        s = prev = scores[0][0]
        best = scores[0][1]
        for x, frac in scores[1:]:
            if x - prev <= 8:
                prev = x
                best = max(best, frac)
            else:
                clusters.append(((s + prev) // 2, best))
                s = prev = x
                best = frac
        clusters.append(((s + prev) // 2, best))
    return clusters


def grand_bars(lum, treble, bass, w, n_meas: int):
    """Full-height barlines. frac>=0.85 is a real bar on this scan."""
    clusters = bar_candidates(lum, treble, bass, w)
    hi = [x for x, frac in clusters if frac >= 0.85]
    if len(hi) == n_meas + 1:
        return hi
    # Fall back: among strong bars, drop the weakest extras or keep all.
    return hi


def positions_of(heads):
    return sorted(p for _, p in heads)


def main():
    systems_xml = parse_xml_ordered()
    print(f"xml systems {len(systems_xml)}")
    doc = fitz.open(PDF)
    xml_i = 0
    for page_i in range(doc.page_count):
        im, zoom, _ = render_page(page_i)
        systems, lum = find_systems(im)
        print(f"\n# page {page_i+1} image-systems {len(systems)} xml-from {systems_xml[xml_i][0]['n'] if xml_i < len(systems_xml) else '?'}")
        if len(systems) != 0 and xml_i + len(systems) <= len(systems_xml):
            pass
        for si, (treble, bass) in enumerate(systems):
            if xml_i >= len(systems_xml):
                print("  extra image system")
                continue
            xml_sys = systems_xml[xml_i]
            xml_i += 1
            w = im.size[0]
            exp = len(xml_sys)
            bars = grand_bars(lum, treble, bass, w, exp)
            edges = bars
            # drop a leading bar that is the system start
            spans = []
            if len(edges) >= 2:
                for a, b in zip(edges, edges[1:]):
                    if b - a > 30:
                        spans.append((a, b))
            label = f"m{xml_sys[0]['n']}-m{xml_sys[-1]['n']}"
            if len(spans) != exp:
                print(f"  ALIGN FAIL {label} spans {len(spans)} != {exp} xs={edges}")
                continue
            for (a, b), m in zip(spans, xml_sys):
                # First span of a system includes clef/key ink.
                left_pad = 70 if a == spans[0][0] else 8
                rh = positions_of(noteheads(im, lum, treble, a + left_pad, b - 4, pad_up=16, pad_down=6))
                lh = positions_of(noteheads(im, lum, bass, a + left_pad, b - 4, pad_up=8, pad_down=14))

                def cover(xml_pos, xml_kind, pdf_pos):
                    used = [False] * len(pdf_pos)
                    filled_miss = []
                    hollow_miss = []
                    for p, k in zip(xml_pos, xml_kind):
                        hit = None
                        for i, q in enumerate(pdf_pos):
                            if not used[i] and abs(q - p) <= 1:
                                hit = i
                                break
                        if hit is None:
                            bucket = hollow_miss if k in ("whole", "half", "breve") else filled_miss
                            bucket.append(p)
                        else:
                            used[hit] = True
                    return filled_miss, hollow_miss

                for side, pdf, staff in (("RH", rh, 1), ("LH", lh, 2)):
                    filled_miss, hollow_miss = cover(m["pos"][staff], m["kind"][staff], pdf)
                    n_filled = sum(k not in ("whole", "half", "breve") for k in m["kind"][staff])
                    if not filled_miss or n_filled == 0 or len(filled_miss) / n_filled < 0.45:
                        if filled_miss and len(filled_miss) / max(1, n_filled) >= 0.25:
                            print(f"  part m{m['n']} {side} {len(filled_miss)}/{n_filled}")
                        continue
                    best_hit, best_d = 0, 0
                    filled_pos = [
                        p for p, k in zip(m["pos"][staff], m["kind"][staff]) if k not in ("whole", "half", "breve")
                    ]
                    for d in range(-14, 15):
                        used = [False] * len(pdf)
                        hit = 0
                        for p in filled_pos:
                            for i, q in enumerate(pdf):
                                if not used[i] and abs(q - (p + d)) <= 1:
                                    used[i] = True
                                    hit += 1
                                    break
                        if hit > best_hit:
                            best_hit, best_d = hit, d
                    print(
                        f"  FAIL m{m['n']} {side} {len(filled_miss)}/{n_filled} bestShift {best_d} hits {best_hit}/{n_filled}"
                    )
        print(f"  xml cursor now {xml_i}")


if __name__ == "__main__":
    main()

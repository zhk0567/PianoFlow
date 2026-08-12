# -*- coding: utf-8 -*-
"""Close clear Castle SOP gaps: opening duration drift + missing PDF final m49.

Still omrDraft — does NOT promote.

Pitch blockers (do NOT guess-rewrite):
- m21–24: PDF crops + LLM vision + staff-geometry disagree; no 2nd authoritative source.
- m40–48: prior p2 rewrite not re-signed measure-by-measure this round.
See scripts/_audit_castle_m21_blockers.py and docs/omr_audit/hisaishi_castle_in_the_sky_SOP.md.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _fix_omr_openings import (  # noqa: E402
    ET,
    append_backup,
    convert,
    load,
    make_note,
    measures,
    q,
    save,
)


def fix_opening_durations(root, ns: str) -> int:
    """divisions=6: eighth=3, quarter=6. Repair corrupted m1/m3/m5 durations."""
    by = {m.get("number"): m for m in measures(root, ns)}
    fixed = 0
    for num in ("1", "3", "5"):
        m = by[num]
        notes = [el for el in m if (el.tag.replace(ns, "") if ns else el.tag) == "note"]
        # RH notes before backup; expect 4 RH + 1 LH
        rh = []
        for el in notes:
            staff = el.find(q(ns, "staff"))
            if staff is not None and staff.text == "1":
                rh.append(el)
        if len(rh) < 4:
            raise SystemExit(f"m{num}: expected ≥4 RH notes, got {len(rh)}")
        # pattern: dotted-quarter(9), eighth(3), quarter(6), quarter(6)
        targets = [9, 3, 6, 6]
        for el, dur in zip(rh[:4], targets):
            d = el.find(q(ns, "duration"))
            if d is None:
                raise SystemExit(f"m{num}: missing duration")
            if int(d.text) != dur:
                d.text = str(dur)
                fixed += 1
    return fixed


def append_pdf_final_m49(root, ns: str) -> bool:
    """PDF p2 bottom: measure 49 = A4 whole / A2 whole + light-heavy."""
    part = root.find(q(ns, "part"))
    ms = measures(root, ns)
    by = {m.get("number"): m for m in ms}
    if "49" in by:
        # ensure content
        m = by["49"]
        for el in list(m):
            tag = el.tag.replace(ns, "") if ns else el.tag
            if tag in ("note", "backup", "forward", "barline"):
                m.remove(el)
        m.append(make_note(ns, step="A", octave=4, dur=24, typ="whole", staff=1, voice=1))
        append_backup(m, ns, 24)
        m.append(make_note(ns, step="A", octave=2, dur=24, typ="whole", staff=2, voice=5))
        bl = ET.Element(q(ns, "barline"))
        bl.set("location", "right")
        bs = ET.SubElement(bl, q(ns, "bar-style"))
        bs.text = "light-heavy"
        m.append(bl)
        return False

    # Remove final barline from m48 (penultimate E5/C3 stays)
    if "48" in by:
        m48 = by["48"]
        for el in list(m48):
            tag = el.tag.replace(ns, "") if ns else el.tag
            if tag == "barline":
                m48.remove(el)

    new_m = ET.Element(q(ns, "measure"))
    new_m.set("number", "49")
    new_m.append(make_note(ns, step="A", octave=4, dur=24, typ="whole", staff=1, voice=1))
    append_backup(new_m, ns, 24)
    new_m.append(make_note(ns, step="A", octave=2, dur=24, typ="whole", staff=2, voice=5))
    bl = ET.SubElement(new_m, q(ns, "barline"))
    bl.set("location", "right")
    bs = ET.SubElement(bl, q(ns, "bar-style"))
    bs.text = "light-heavy"
    part.append(new_m)
    return True


def main() -> None:
    sid = "hisaishi_castle_in_the_sky"
    tree, root, ns = load(sid)
    n = fix_opening_durations(root, ns)
    appended = append_pdf_final_m49(root, ns)
    save(sid, tree)
    convert(sid)
    print(
        f"[PianoFlow/omr] castle SOP gaps: fixed {n} opening durations; "
        f"m49 A4/A2 {'appended' if appended else 'rewritten'}; still omrDraft"
    )


if __name__ == "__main__":
    main()

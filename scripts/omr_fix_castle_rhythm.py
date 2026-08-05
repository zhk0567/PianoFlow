#!/usr/bin/env python3
"""Fix hisaishi_castle_in_the_sky OMR rhythm holes (RH duration sum < 24).

PDF/arrangement motif is half + 2 eighths + quarter (=24 div). OMR often wrote
dotted-quarter + broken tuplet (=21). Also fixes a few other short bars.

Does NOT set scoreKind=formal.
"""

from __future__ import annotations

import copy
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))
from musicxml_to_score import local  # noqa: E402

XML = REPO / "assets" / "scores" / "musicxml" / "hisaishi_castle_in_the_sky.musicxml"
THIRD = REPO / "third_party" / "scores_musicxml" / "hisaishi_castle_in_the_sky.musicxml"


def note_meta(el: ET.Element) -> dict:
    m = {
        "chord": False,
        "rest": False,
        "grace": False,
        "dur": None,
        "typ": None,
        "staff": None,
        "dots": 0,
        "has_tm": False,
    }
    for c in el:
        t = local(c.tag)
        if t == "chord":
            m["chord"] = True
        elif t == "rest":
            m["rest"] = True
        elif t == "grace":
            m["grace"] = True
        elif t == "duration":
            m["dur"] = c
        elif t == "type":
            m["typ"] = c
        elif t == "staff":
            m["staff"] = (c.text or "").strip()
        elif t == "dot":
            m["dots"] += 1
        elif t == "time-modification":
            m["has_tm"] = True
    return m


def rh_notes(meas: ET.Element) -> list[ET.Element]:
    out = []
    for el in list(meas):
        if local(el.tag) != "note":
            continue
        m = note_meta(el)
        if m["chord"] or m["grace"] or m["rest"]:
            continue
        if m["staff"] == "1":
            out.append(el)
    return out


def clear_tuplets_and_dots(note: ET.Element) -> None:
    for c in list(note):
        t = local(c.tag)
        if t in ("time-modification", "dot"):
            note.remove(c)
        elif t == "notations":
            for n in list(c):
                if local(n.tag) == "tuplet":
                    c.remove(n)
            if len(list(c)) == 0:
                note.remove(c)


def set_note(note: ET.Element, *, typ: str, dur: int, dots: int = 0) -> None:
    m = note_meta(note)
    clear_tuplets_and_dots(note)
    if m["typ"] is not None:
        m["typ"].text = typ
    else:
        ET.SubElement(note, "type").text = typ
    if m["dur"] is not None:
        m["dur"].text = str(dur)
    else:
        ET.SubElement(note, "duration").text = str(dur)
    # re-read and add dots after type
    if dots:
        kids = list(note)
        insert_at = len(kids)
        for i, c in enumerate(kids):
            if local(c.tag) == "type":
                insert_at = i + 1
                break
        for _ in range(dots):
            note.insert(insert_at, ET.Element("dot"))
            insert_at += 1


def set_backup(meas: ET.Element, dur: int) -> None:
    for el in list(meas):
        if local(el.tag) == "backup":
            for c in el:
                if local(c.tag) == "duration":
                    c.text = str(dur)
            return


def rh_sum(meas: ET.Element) -> int:
    s = 0
    for n in rh_notes(meas):
        m = note_meta(n)
        if m["dur"] is not None and m["dur"].text:
            s += int(m["dur"].text)
    return s


def fix_motif_half_eighths(meas: ET.Element) -> bool:
    """dottedQ(9)+tm8(2)+tmQ(4)+Q(6)=21 → half(12)+8(3)+8(3)+Q(6)=24."""
    rh = rh_notes(meas)
    if len(rh) != 4 or rh_sum(meas) != 21:
        return False
    metas = [note_meta(n) for n in rh]
    if not (
        metas[0]["typ"] is not None
        and metas[0]["typ"].text == "quarter"
        and metas[0]["dots"] == 1
        and int(metas[0]["dur"].text) == 9
        and metas[1]["has_tm"]
        and metas[2]["has_tm"]
        and int(metas[3]["dur"].text) == 6
    ):
        return False
    set_note(rh[0], typ="half", dur=12, dots=0)
    set_note(rh[1], typ="eighth", dur=3)
    set_note(rh[2], typ="eighth", dur=3)
    set_note(rh[3], typ="quarter", dur=6)
    set_backup(meas, 24)
    return True


def fix_m23_four_quarters(meas: ET.Element) -> bool:
    rh = rh_notes(meas)
    if len(rh) != 4 or rh_sum(meas) != 16:
        return False
    if not all(note_meta(n)["has_tm"] for n in rh):
        return False
    for n in rh:
        set_note(n, typ="quarter", dur=6)
    set_backup(meas, 24)
    return True


def fix_m27(meas: ET.Element) -> bool:
    rh = rh_notes(meas)
    if len(rh) != 5 or rh_sum(meas) != 18:
        return False
    # Q tm, 8 tm, 8 tm, Q tm, Q → normal 6,3,3,6,6
    set_note(rh[0], typ="quarter", dur=6)
    set_note(rh[1], typ="eighth", dur=3)
    set_note(rh[2], typ="eighth", dur=3)
    set_note(rh[3], typ="quarter", dur=6)
    set_note(rh[4], typ="quarter", dur=6)
    set_backup(meas, 24)
    return True


def fix_m15(meas: ET.Element) -> bool:
    rh = rh_notes(meas)
    if len(rh) != 6 or rh_sum(meas) != 21:
        return False
    # three tuplet 8ths + 8th + Q + Q → three 8ths + 8th + Q + Q = 24
    for i in range(3):
        set_note(rh[i], typ="eighth", dur=3)
    set_note(rh[3], typ="eighth", dur=3)
    set_note(rh[4], typ="quarter", dur=6)
    set_note(rh[5], typ="quarter", dur=6)
    set_backup(meas, 24)
    return True


def fix_m21(meas: ET.Element) -> bool:
    rh = rh_notes(meas)
    if len(rh) != 6 or rh_sum(meas) != 21:
        return False
    # last two were tm 2+4 → 3+6
    set_note(rh[4], typ="eighth", dur=3)
    set_note(rh[5], typ="quarter", dur=6)
    set_backup(meas, 24)
    return True


def fix_m47(meas: ET.Element) -> bool:
    rh = rh_notes(meas)
    if len(rh) != 6 or rh_sum(meas) != 18:
        return False
    for i in range(4):
        set_note(rh[i], typ="eighth", dur=3)
    set_note(rh[4], typ="quarter", dur=6)
    set_note(rh[5], typ="quarter", dur=6)
    set_backup(meas, 24)
    return True


def main() -> int:
    tree = ET.parse(XML)
    root = tree.getroot()
    log: list[str] = []
    for meas in root.iter():
        if local(meas.tag) != "measure":
            continue
        num = meas.attrib.get("number", "?")
        before = rh_sum(meas)
        changed = False
        if num == "23":
            changed = fix_m23_four_quarters(meas)
        elif num == "27":
            changed = fix_m27(meas)
        elif num == "15":
            changed = fix_m15(meas)
        elif num == "21":
            changed = fix_m21(meas)
        elif num == "47":
            changed = fix_m47(meas)
        else:
            changed = fix_motif_half_eighths(meas)
        if changed:
            log.append(f"m{num}: {before}→{rh_sum(meas)}")

    # verify
    bad = []
    for meas in root.iter():
        if local(meas.tag) != "measure":
            continue
        num = meas.attrib.get("number", "?")
        if num == "0":
            continue
        s = rh_sum(meas)
        if s and s != 24:
            bad.append((num, s))

    tree.write(XML, encoding="UTF-8", xml_declaration=True)
    THIRD.write_bytes(XML.read_bytes())
    print("fixed:", ", ".join(log) if log else "(none)")
    print("remaining RH!=24:", bad if bad else "none")
    return 0 if not bad else 1


if __name__ == "__main__":
    raise SystemExit(main())

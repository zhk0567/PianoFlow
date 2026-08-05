#!/usr/bin/env python3
"""Fix remaining Moonlight Sonata RH plain-eighth runs into triplets.

After divisions drop to 4, Audiveris often wrote 12 plain eighths (sum=24)
instead of 12 triplet-eighths (sum=16). Scale measure to divisions*3 when needed,
then set duration=div/3 with 3:2 time-modification.
"""

from __future__ import annotations

import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))
from musicxml_to_score import local  # noqa: E402

XML = REPO / "assets" / "scores" / "musicxml" / "beethoven_moonlight_sonata.musicxml"
THIRD = REPO / "third_party" / "scores_musicxml" / "beethoven_moonlight_sonata.musicxml"


def get_div(meas: ET.Element, default: int) -> int:
    for el in meas:
        if local(el.tag) != "attributes":
            continue
        for c in el:
            if local(c.tag) == "divisions" and c.text:
                return int(c.text)
    return default


def set_div(meas: ET.Element, div: int) -> None:
    for el in meas:
        if local(el.tag) != "attributes":
            continue
        for c in el:
            if local(c.tag) == "divisions":
                c.text = str(div)
                return
        # insert divisions at start of attributes
        d = ET.Element("divisions")
        d.text = str(div)
        el.insert(0, d)
        return
    # create attributes
    attrs = ET.Element("attributes")
    d = ET.SubElement(attrs, "divisions")
    d.text = str(div)
    meas.insert(0, attrs)


def scale_all_durations(meas: ET.Element, factor: int) -> None:
    for el in meas.iter():
        if local(el.tag) == "duration" and el.text and el.text.isdigit():
            el.text = str(int(el.text) * factor)


def staff1_plain_eighths(meas: ET.Element) -> list[ET.Element]:
    out = []
    for el in list(meas):
        if local(el.tag) != "note":
            continue
        staff = typ = None
        dur = 0
        tm = chord = grace = False
        for c in el:
            t = local(c.tag)
            if t == "staff":
                staff = c.text
            elif t == "type":
                typ = c.text
            elif t == "duration" and c.text:
                dur = int(c.text)
            elif t == "time-modification":
                tm = True
            elif t == "chord":
                chord = True
            elif t == "grace":
                grace = True
        if chord or grace or staff != "1" or typ != "eighth" or tm:
            continue
        out.append(el)
    return out


def apply_triplet(note: ET.Element, dur: int, pos: int) -> None:
    for c in list(note):
        t = local(c.tag)
        if t in ("time-modification", "beam"):
            note.remove(c)
        elif t == "duration":
            c.text = str(dur)
        elif t == "notations":
            for n in list(c):
                if local(n.tag) == "tuplet":
                    c.remove(n)
            if len(list(c)) == 0:
                note.remove(c)
    # ensure duration exists
    if not any(local(c.tag) == "duration" for c in note):
        ET.SubElement(note, "duration").text = str(dur)
    # insert time-modification after type
    tm = ET.Element("time-modification")
    ET.SubElement(tm, "actual-notes").text = "3"
    ET.SubElement(tm, "normal-notes").text = "2"
    kids = list(note)
    insert_at = len(kids)
    for i, c in enumerate(kids):
        if local(c.tag) == "type":
            insert_at = i + 1
            break
    note.insert(insert_at, tm)
    beam = ET.Element("beam", number="1")
    beam.text = "begin" if pos == 0 else ("end" if pos == 2 else "continue")
    note.append(beam)
    if pos in (0, 2):
        notations = None
        for c in note:
            if local(c.tag) == "notations":
                notations = c
                break
        if notations is None:
            notations = ET.SubElement(note, "notations")
        if pos == 0:
            ET.SubElement(
                notations, "tuplet", type="start", number="1", placement="above"
            )
        else:
            ET.SubElement(notations, "tuplet", type="stop", number="1")


def fix_backup_to(meas: ET.Element, dur: int) -> None:
    for el in meas:
        if local(el.tag) == "backup":
            for c in el:
                if local(c.tag) == "duration":
                    c.text = str(dur)
            return


def main() -> int:
    tree = ET.parse(XML)
    root = tree.getroot()
    div = 12
    fixed = []
    for meas in root.iter():
        if local(meas.tag) != "measure":
            continue
        num = meas.attrib.get("number", "?")
        div = get_div(meas, div)
        eighths = staff1_plain_eighths(meas)
        if len(eighths) < 6 or len(eighths) % 3 != 0:
            continue
        plain_sum = 0
        for n in eighths:
            for c in n:
                if local(c.tag) == "duration" and c.text:
                    plain_sum += int(c.text)
        expect = div * 4
        # classic underflow/overflow: 12 eighths written as non-triplet
        if not (plain_sum > expect and abs(plain_sum / expect - 1.5) < 0.05):
            # also accept exactly 12 eighths of dur=div/2
            if not (len(eighths) == 12 and plain_sum == 12 * (div // 2) and plain_sum != expect):
                continue
        # scale divisions to multiple of 3 if needed
        if div % 3 != 0:
            scale_all_durations(meas, 3)
            div = div * 3
            set_div(meas, div)
            expect = div * 4
            # refresh eighth list (same elements, new durs)
            eighths = staff1_plain_eighths(meas)
        target = div // 3
        for i, n in enumerate(eighths):
            apply_triplet(n, target, i % 3)
        fix_backup_to(meas, expect)
        fixed.append(num)

    tree.write(XML, encoding="UTF-8", xml_declaration=True)
    THIRD.write_bytes(XML.read_bytes())
    print(f"fixed measures ({len(fixed)}):", ",".join(fixed))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

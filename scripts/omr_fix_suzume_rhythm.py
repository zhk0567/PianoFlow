#!/usr/bin/env python3
"""Fix radwimps_suzume OMR rhythm: tuplet-16th dur=2 → plain 16th dur=3.

Many bars summed to 45/48 because Audiveris wrote 3:2 sixteenths too short.
Does NOT promote to formal.
"""

from __future__ import annotations

import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))
from musicxml_to_score import local  # noqa: E402

XML = REPO / "assets" / "scores" / "musicxml" / "radwimps_suzume.musicxml"
THIRD = REPO / "third_party" / "scores_musicxml" / "radwimps_suzume.musicxml"


def fix_note(note: ET.Element) -> int:
    """Return added duration units."""
    staff = voice = typ = None
    dur_el = None
    tm_el = None
    chord = grace = False
    for c in list(note):
        t = local(c.tag)
        if t == "staff":
            staff = c.text
        elif t == "voice":
            voice = c.text
        elif t == "type":
            typ = c.text
        elif t == "duration":
            dur_el = c
        elif t == "time-modification":
            tm_el = c
        elif t == "chord":
            chord = True
        elif t == "grace":
            grace = True
    if chord or grace or staff != "1" or (voice or "1") != "1" or dur_el is None:
        return 0
    dur = int(dur_el.text or 0)
    added = 0
    if typ == "16th" and tm_el is not None and dur == 2:
        dur_el.text = "3"
        note.remove(tm_el)
        for c in list(note):
            if local(c.tag) == "notations":
                for n in list(c):
                    if local(n.tag) == "tuplet":
                        c.remove(n)
                if len(list(c)) == 0:
                    note.remove(c)
        added += 1
    elif typ == "eighth" and tm_el is not None and dur == 4:
        # m18: short tuplet eighth
        dur_el.text = "6"
        note.remove(tm_el)
        for c in list(note):
            if local(c.tag) == "notations":
                for n in list(c):
                    if local(n.tag) == "tuplet":
                        c.remove(n)
                if len(list(c)) == 0:
                    note.remove(c)
        added += 2
    return added


def voice1_sum(meas: ET.Element) -> int:
    s = 0
    for el in meas:
        if local(el.tag) != "note":
            continue
        staff = voice = None
        dur = 0
        chord = grace = False
        for c in el:
            t = local(c.tag)
            if t == "staff":
                staff = c.text
            elif t == "voice":
                voice = c.text
            elif t == "duration" and c.text:
                dur = int(c.text)
            elif t == "chord":
                chord = True
            elif t == "grace":
                grace = True
        if staff == "1" and (voice or "1") == "1" and not chord and not grace:
            s += dur
    return s


def set_first_backup(meas: ET.Element, dur: int) -> None:
    for el in meas:
        if local(el.tag) == "backup":
            for c in el:
                if local(c.tag) == "duration":
                    c.text = str(dur)
            return


def main() -> int:
    tree = ET.parse(XML)
    root = tree.getroot()
    log = []
    for meas in root.iter():
        if local(meas.tag) != "measure":
            continue
        num = meas.attrib.get("number", "?")
        before = voice1_sum(meas)
        added = 0
        for el in list(meas):
            if local(el.tag) == "note":
                added += fix_note(el)
        after = voice1_sum(meas)
        if added:
            set_first_backup(meas, after)
            log.append(f"m{num}:{before}→{after}(+{added})")

    bad = []
    for meas in root.iter():
        if local(meas.tag) != "measure":
            continue
        num = meas.attrib.get("number", "?")
        s = voice1_sum(meas)
        if num != "0" and s and s != 48:
            bad.append((num, s))

    tree.write(XML, encoding="UTF-8", xml_declaration=True)
    THIRD.write_bytes(XML.read_bytes())
    print("fixed:", ", ".join(log))
    print("remaining voice1!=48:", bad if bad else "none")
    return 0 if not bad else 1


if __name__ == "__main__":
    raise SystemExit(main())

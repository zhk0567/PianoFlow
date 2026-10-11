"""R12: rewrite visually confirmed 诀别书 measures from the PDF scan.

Not a promotion to formal.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
ASSET = REPO / "assets/scores/musicxml/jue_bie_shu.musicxml"
SYNC_XML = [
    REPO / "third_party/scores_musicxml/jue_bie_shu.musicxml",
    REPO / "clients/web/scores/musicxml/jue_bie_shu.musicxml",
    REPO / "clients/android/app/src/main/assets/scores/musicxml/jue_bie_shu.musicxml",
]
SYNC_JSON = [
    REPO / "clients/web/scores/jue_bie_shu.json",
    REPO / "clients/android/app/src/main/assets/scores/jue_bie_shu.json",
]


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def pitch_of(note: ET.Element) -> tuple | None:
    pitch = next((c for c in note if local(c.tag) == "pitch"), None)
    if pitch is None:
        return None
    step = next(c.text for c in pitch if local(c.tag) == "step")
    octave = int(next(c.text for c in pitch if local(c.tag) == "octave"))
    return step, octave


def clear_music(measure: ET.Element) -> None:
    keep = [el for el in list(measure) if local(el.tag) not in ("note", "backup", "forward")]
    for el in list(measure):
        measure.remove(el)
    for el in keep:
        measure.append(el)


def N(step: str, octave: int, dur: int, typ: str, staff: int, voice: int, *, chord=False, alter=None, dots=0) -> ET.Element:
    n = ET.Element("note")
    if chord:
        ET.SubElement(n, "chord")
    p = ET.SubElement(n, "pitch")
    ET.SubElement(p, "step").text = step
    if alter is not None:
        ET.SubElement(p, "alter").text = str(alter)
    ET.SubElement(p, "octave").text = str(octave)
    ET.SubElement(n, "duration").text = str(dur)
    ET.SubElement(n, "voice").text = str(voice)
    ET.SubElement(n, "type").text = typ
    for _ in range(dots):
        ET.SubElement(n, "dot")
    ET.SubElement(n, "staff").text = str(staff)
    return n


def emit(measure: ET.Element, staff_notes: dict[int, list]) -> None:
    """staff_notes: staff -> list of events. Event is list of (step,oct,dur,typ,kwargs)."""
    first = True
    for staff in sorted(staff_notes):
        if not first:
            b = ET.SubElement(measure, "backup")
            ET.SubElement(b, "duration").text = "16"
        first = False
        voice = 1 if staff == 1 else 5
        for ev in staff_notes[staff]:
            tones, dur, typ = ev[0], ev[1], ev[2]
            extra = ev[3] if len(ev) > 3 else {}
            for i, tone in enumerate(tones):
                step, octv = tone[0], tone[1]
                alter = tone[2] if len(tone) > 2 else None
                measure.append(
                    N(step, octv, dur, typ, staff, voice, chord=i > 0, alter=alter, dots=extra.get("dots", 0))
                )


def first_rh(measure: ET.Element) -> tuple | None:
    for el in measure:
        if local(el.tag) != "note":
            continue
        staff = next((c.text for c in el if local(c.tag) == "staff"), "1")
        if staff != "1":
            continue
        if any(local(c.tag) == "rest" for c in el):
            continue
        return pitch_of(el)
    return None


def main() -> int:
    tree = ET.parse(ASSET)
    root = tree.getroot()
    part = next(el for el in root if local(el.tag) == "part")
    by_num = {m.get("number"): m for m in part if local(m.tag) == "measure"}
    done = []

    # m49: fifths, not octaves. dotted half + quarter.
    m = by_num["49"]
    if first_rh(m) == ("F", 5) and any(
        pitch_of(n) == ("F", 6) for n in m if local(n.tag) == "note"
    ):
        clear_music(m)
        emit(
            m,
            {
                1: [([("F", 5), ("C", 6)], 12, "half", {"dots": 1}), ([("A", 5), ("E", 6)], 4, "quarter")],
                2: [
                    ([("B", 1, -1), ("B", 2, -1)], 2, "eighth"),
                    ([("F", 3)], 2, "eighth"),
                    ([("B", 3, -1)], 2, "eighth"),
                    ([("D", 4)], 2, "eighth"),
                    ([("F", 4)], 2, "eighth"),
                    ([("D", 4)], 2, "eighth"),
                    ([("B", 3, -1)], 2, "eighth"),
                    ([("F", 3)], 2, "eighth"),
                ],
            },
        )
        done.append("49")

    rh77 = {
        1: [
            ([("D", 4)], 2, "eighth"),
            ([("G", 4), ("B", 4)], 2, "eighth"),
            ([("A", 4)], 1, "16th"),
            ([("G", 4)], 1, "16th"),
            ([("G", 4)], 2, "eighth"),
            ([("G", 4), ("B", 4)], 2, "eighth"),
            ([("G", 4), ("B", 4)], 2, "eighth"),
            ([("G", 4)], 2, "eighth"),
            ([("E", 4)], 2, "eighth"),
        ]
    }

    m = by_num["73"]
    if first_rh(m) == ("A", 4):
        clear_music(m)
        emit(
            m,
            {
                **rh77,
                2: [
                    ([("F", 3)], 12, "half", {"dots": 1}),
                    ([("A", 3)], 2, "eighth"),
                    ([("C", 4)], 2, "eighth"),
                ],
            },
        )
        done.append("73")

    rh78 = {
        1: [
            ([("G", 4)], 1, "16th"),
            ([("F", 4)], 1, "16th"),
            ([("E", 4)], 1, "16th"),
            ([("D", 4)], 1, "16th"),
            ([("F", 4)], 1, "16th"),
            ([("E", 4)], 1, "16th"),
            ([("D", 4)], 1, "16th"),
            ([("C", 4)], 1, "16th"),
            ([("E", 4)], 1, "16th"),
            ([("D", 4)], 1, "16th"),
            ([("C", 4)], 1, "16th"),
            ([("B", 3, -1)], 1, "16th"),
            ([("D", 4)], 1, "16th"),
            ([("C", 4)], 1, "16th"),
            ([("B", 3, -1)], 1, "16th"),
            ([("A", 3)], 1, "16th"),
        ]
    }

    m = by_num["74"]
    if first_rh(m) == ("G", 4) and any(
        pitch_of(n) == ("C", 2) for n in m if local(n.tag) == "note"
    ):
        clear_music(m)
        emit(
            m,
            {
                **rh78,
                2: [
                    ([("F", 3)], 12, "half", {"dots": 1}),
                    ([("A", 3)], 2, "eighth"),
                    ([("C", 4)], 2, "eighth"),
                ],
            },
        )
        done.append("74")

    m = by_num["75"]
    if first_rh(m) == ("F", 4):
        clear_music(m)
        emit(
            m,
            {
                1: [
                    ([("C", 4)], 2, "eighth"),
                    ([("E", 4)], 1, "16th"),
                    ([("G", 4)], 1, "16th"),
                    ([("G", 4)], 2, "eighth"),
                    ([("E", 4)], 2, "eighth"),
                    ([("G", 4)], 2, "eighth"),
                    ([("G", 4), ("B", 4)], 2, "eighth"),
                    ([("G", 4)], 2, "eighth"),
                    ([("E", 4)], 2, "eighth"),
                ],
                2: [
                    ([("F", 3)], 8, "half"),
                    ([("A", 3)], 2, "eighth"),
                    ([("C", 4)], 2, "eighth"),
                    ([("A", 3)], 2, "eighth"),
                    ([("F", 3)], 2, "eighth"),
                ],
            },
        )
        done.append("75")

    m = by_num["78"]
    if any(pitch_of(n) == ("D", 3) for n in m if local(n.tag) == "note"):
        # keep RH 16ths, replace LH
        clear_music(m)
        emit(
            m,
            {
                **rh78,
                2: [
                    ([("F", 3)], 2, "eighth"),
                    ([("A", 3), ("C", 4)], 2, "eighth"),
                    ([("F", 3)], 2, "eighth"),
                    ([("A", 3), ("C", 4)], 2, "eighth"),
                    ([("F", 3)], 8, "half"),
                ],
            },
        )
        done.append("78")

    m = by_num["79"]
    if first_rh(m) == ("F", 4):
        clear_music(m)
        emit(
            m,
            {
                1: [
                    ([("C", 4)], 2, "eighth"),
                    ([("G", 4)], 1, "16th"),
                    ([("F", 4)], 1, "16th"),
                    ([("G", 4)], 2, "eighth"),
                    ([("F", 4)], 2, "eighth"),
                    ([("G", 4)], 2, "eighth"),
                    ([("B", 4)], 2, "eighth"),
                    ([("D", 5)], 2, "eighth"),
                    ([("F", 5)], 2, "eighth"),
                ],
                2: [
                    ([("F", 3), ("A", 3)], 2, "eighth"),
                    ([("F", 3), ("A", 3)], 2, "eighth"),
                    ([("F", 3), ("A", 3)], 2, "eighth"),
                    ([("F", 3), ("A", 3)], 2, "eighth"),
                    ([("F", 3), ("A", 3)], 2, "eighth"),
                    ([("F", 3), ("A", 3)], 2, "eighth"),
                    ([("F", 3), ("A", 3)], 2, "eighth"),
                    ([("F", 3), ("A", 3)], 2, "eighth"),
                ],
            },
        )
        done.append("79")

    rh85 = {
        1: [
            ([("D", 5)], 1, "16th"),
            ([("E", 5)], 1, "16th"),
            ([("F", 5)], 1, "16th"),
            ([("G", 5)], 1, "16th"),
            ([("A", 5)], 1, "16th"),
            ([("G", 5)], 1, "16th"),
            ([("F", 5)], 1, "16th"),
            ([("G", 5)], 1, "16th"),
            ([("A", 5)], 1, "16th"),
            ([("C", 6)], 1, "16th"),
            ([("A", 5)], 1, "16th"),
            ([("G", 5)], 1, "16th"),
            ([("F", 5)], 1, "16th"),
            ([("A", 5)], 1, "16th"),
            ([("G", 5)], 1, "16th"),
            ([("F", 5)], 1, "16th"),
        ]
    }

    m = by_num["81"]
    if first_rh(m) == ("D", 5) and any(
        pitch_of(n) == ("A", 4) for n in m if local(n.tag) == "note"
    ):
        # keep LH D-major figure, replace RH with the scale seen on the scan
        lh = []
        for el in list(m):
            if local(el.tag) != "note":
                continue
            staff = next((c.text for c in el if local(c.tag) == "staff"), "1")
            if staff != "2":
                continue
            p = pitch_of(el)
            if p is None:
                continue
            typ = next((c.text for c in el if local(c.tag) == "type"), "eighth")
            dur = int(next(c.text for c in el if local(c.tag) == "duration"))
            if not any(local(c.tag) == "chord" for c in el):
                lh.append([[p], dur, typ])
            else:
                lh[-1][0].append(p)
        clear_music(m)
        emit(m, {**rh85, 2: lh})
        done.append("81")

    m = by_num["86"]
    if any(pitch_of(n) == ("A", 1) for n in m if local(n.tag) == "note"):
        rh = []
        for el in list(m):
            if local(el.tag) != "note":
                continue
            staff = next((c.text for c in el if local(c.tag) == "staff"), "1")
            if staff != "1":
                continue
            p = pitch_of(el)
            if p is None:
                continue
            typ = next((c.text for c in el if local(c.tag) == "type"), "16th")
            dur = int(next(c.text for c in el if local(c.tag) == "duration"))
            if not any(local(c.tag) == "chord" for c in el):
                rh.append([[p], dur, typ])
            else:
                rh[-1][0].append(p)
        clear_music(m)
        emit(
            m,
            {
                1: rh,
                2: [
                    ([("F", 2)], 4, "quarter"),
                    ([("A", 3), ("C", 4), ("E", 4)], 4, "quarter"),
                    ([("A", 3), ("C", 4), ("E", 4)], 2, "eighth"),
                    ([("C", 4), ("E", 4)], 2, "eighth"),
                    ([("C", 4)], 2, "eighth"),
                    ([("A", 3)], 2, "eighth"),
                ],
            },
        )
        done.append("86")

    m = by_num["88"]
    if first_rh(m) == ("C", 6):
        clear_music(m)
        emit(
            m,
            {
                1: [
                    ([("C", 6)], 1, "16th"),
                    ([("B", 5, -1)], 1, "16th"),
                    ([("A", 5)], 1, "16th"),
                    ([("G", 5)], 1, "16th"),
                    ([("F", 5)], 1, "16th"),
                    ([("G", 5)], 1, "16th"),
                    ([("F", 5)], 1, "16th"),
                    ([("E", 5)], 1, "16th"),
                    ([("F", 5)], 4, "quarter"),
                    ([("D", 5)], 2, "eighth"),
                    ([("G", 5)], 2, "eighth"),
                ],
                2: [
                    ([("F", 2)], 2, "eighth"),
                    ([("A", 3), ("C", 4)], 2, "eighth"),
                    ([("A", 3), ("C", 4)], 4, "quarter"),
                    ([("F", 3)], 4, "quarter"),
                    ([("D", 3), ("A", 2)], 4, "quarter"),
                ],
            },
        )
        done.append("88")

    m = by_num["92"]
    if first_rh(m) == ("D", 4):
        clear_music(m)
        emit(
            m,
            {
                1: [
                    ([("C", 5), ("E", 5), ("G", 5)], 8, "half"),
                    ([("C", 4), ("G", 4)], 8, "half"),
                ],
                2: [
                    ([("D", 2), ("A", 2)], 4, "quarter"),
                    ([("D", 2), ("A", 2)], 4, "quarter"),
                    ([("D", 3), ("A", 3)], 4, "quarter"),
                    ([("D", 3), ("F", 3)], 4, "quarter"),
                ],
            },
        )
        done.append("92")

    fig93 = {
        1: [
            ([("G", 5), ("D", 6)], 2, "eighth"),
            ([("A", 5), ("C", 6)], 2, "eighth"),
            ([("A", 5)], 2, "eighth"),
            ([("G", 5), ("D", 6)], 2, "eighth"),
            ([("A", 5), ("C", 6)], 2, "eighth"),
            ([("A", 5)], 2, "eighth"),
            ([("A", 5), ("C", 6)], 2, "eighth"),
            ([("A", 5), ("C", 6)], 2, "eighth"),
        ]
    }
    for num in ("93", "94", "95"):
        m = by_num[num]
        if first_rh(m) != ("F", 6):
            continue
        lh = []
        for el in list(m):
            if local(el.tag) != "note":
                continue
            staff = next((c.text for c in el if local(c.tag) == "staff"), "1")
            if staff != "2":
                continue
            p = pitch_of(el)
            if p is None:
                continue
            typ = next((c.text for c in el if local(c.tag) == "type"), "eighth")
            dur = int(next(c.text for c in el if local(c.tag) == "duration"))
            if not any(local(c.tag) == "chord" for c in el):
                lh.append([[p], dur, typ])
            else:
                lh[-1][0].append(p)
        clear_music(m)
        emit(m, {**fig93, 2: lh})
        done.append(num)

    m = by_num["98"]
    if any(pitch_of(n) == ("A", 2) for n in m if local(n.tag) == "note"):
        rh = []
        for el in list(m):
            if local(el.tag) != "note":
                continue
            staff = next((c.text for c in el if local(c.tag) == "staff"), "1")
            if staff != "1":
                continue
            p = pitch_of(el)
            if p is None:
                continue
            typ = next((c.text for c in el if local(c.tag) == "type"), "eighth")
            dur = int(next(c.text for c in el if local(c.tag) == "duration"))
            alter_el = None
            pitch = next(c for c in el if local(c.tag) == "pitch")
            alt = next((c.text for c in pitch if local(c.tag) == "alter"), None)
            tone = (p[0], p[1], int(alt)) if alt is not None else p
            if not any(local(c.tag) == "chord" for c in el):
                rh.append([[tone], dur, typ])
            else:
                rh[-1][0].append(tone)
        clear_music(m)
        emit(
            m,
            {
                1: rh,
                2: [
                    ([("F", 2)], 2, "eighth"),
                    ([("A", 3), ("C", 4), ("E", 4)], 2, "eighth"),
                    ([("A", 3), ("C", 4), ("E", 4)], 4, "quarter"),
                    ([("A", 3), ("C", 4), ("E", 4)], 2, "eighth"),
                    ([("C", 4)], 2, "eighth"),
                    ([("A", 3)], 2, "eighth"),
                    ([("F", 3)], 2, "eighth"),
                ],
            },
        )
        done.append("98")

    m = by_num["100"]
    if first_rh(m) == ("F", 5):
        clear_music(m)
        emit(
            m,
            {
                1: [
                    ([("F", 5), ("A", 5)], 1, "16th"),
                    ([("G", 5), ("B", 5, -1)], 1, "16th"),
                    ([("A", 5), ("C", 6)], 2, "eighth"),
                    ([("B", 5, -1), ("D", 6)], 2, "eighth"),
                    ([("A", 5), ("C", 6)], 2, "eighth"),
                    ([("F", 5)], 6, "quarter", {"dots": 1}),
                    ([("D", 5)], 1, "16th"),
                    ([("F", 5)], 1, "16th"),
                ],
                2: [
                    ([("F", 2)], 2, "eighth"),
                    ([("A", 3), ("C", 4)], 2, "eighth"),
                    ([("A", 3), ("C", 4)], 4, "quarter"),
                    ([("F", 3)], 4, "quarter"),
                    ([("D", 3), ("A", 2)], 4, "quarter"),
                ],
            },
        )
        done.append("100")

    m = by_num["103"]
    if any(pitch_of(n) == ("B", 5) for n in m if local(n.tag) == "note"):
        lh = []
        for el in list(m):
            if local(el.tag) != "note":
                continue
            staff = next((c.text for c in el if local(c.tag) == "staff"), "1")
            if staff != "2":
                continue
            p = pitch_of(el)
            if p is None:
                continue
            typ = next((c.text for c in el if local(c.tag) == "type"), "eighth")
            dur = int(next(c.text for c in el if local(c.tag) == "duration"))
            if not any(local(c.tag) == "chord" for c in el):
                lh.append([[p], dur, typ])
            else:
                lh[-1][0].append(p)
        clear_music(m)
        emit(m, {1: [([("D", 5), ("F", 5)], 16, "whole")], 2: lh})
        done.append("103")

    print("rewrote", ",".join(done) if done else "nothing")
    if done:
        tree.write(ASSET, encoding="utf-8", xml_declaration=True)
    for dest in SYNC_XML:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ASSET, dest)
    r = subprocess.run(
        [sys.executable, "-u", str(REPO / "scripts/musicxml_to_score.py"), "--id", "jue_bie_shu"],
        cwd=REPO,
    )
    if r.returncode != 0:
        return r.returncode
    src_json = REPO / "assets/scores/jue_bie_shu.json"
    for dest in SYNC_JSON:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_json, dest)
    print("synced; still omrDraft")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

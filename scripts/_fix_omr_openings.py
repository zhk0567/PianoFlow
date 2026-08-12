#!/usr/bin/env python3
"""One-shot / reusable MusicXML opening fixes for OMR drafts (omrDraft only)."""
from __future__ import annotations

import copy
import shutil
import subprocess
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "assets" / "scores" / "musicxml"
THIRD = ROOT / "third_party" / "scores_musicxml"


def ns_of(root: ET.Element) -> str:
    return root.tag.split("}")[0] + "}" if root.tag.startswith("{") else ""


def q(ns: str, name: str) -> str:
    return f"{ns}{name}" if ns else name


def make_pitch(ns: str, step: str, octave: int, alter: int | None = None) -> ET.Element:
    pitch = ET.Element(q(ns, "pitch"))
    s = ET.SubElement(pitch, q(ns, "step"))
    s.text = step
    if alter is not None and alter != 0:
        a = ET.SubElement(pitch, q(ns, "alter"))
        a.text = str(alter)
    o = ET.SubElement(pitch, q(ns, "octave"))
    o.text = str(octave)
    return pitch


def make_note(
    ns: str,
    *,
    step: str | None,
    octave: int | None,
    dur: int,
    typ: str,
    staff: int,
    voice: int,
    alter: int | None = None,
    rest: bool = False,
    chord: bool = False,
    dotted: bool = False,
) -> ET.Element:
    note = ET.Element(q(ns, "note"))
    if chord:
        ET.SubElement(note, q(ns, "chord"))
    if rest:
        ET.SubElement(note, q(ns, "rest"))
    else:
        assert step is not None and octave is not None
        note.append(make_pitch(ns, step, octave, alter))
    d = ET.SubElement(note, q(ns, "duration"))
    d.text = str(dur)
    v = ET.SubElement(note, q(ns, "voice"))
    v.text = str(voice)
    t = ET.SubElement(note, q(ns, "type"))
    t.text = typ
    if dotted:
        ET.SubElement(note, q(ns, "dot"))
    st = ET.SubElement(note, q(ns, "staff"))
    st.text = str(staff)
    return note


def clear_notes(measure: ET.Element, ns: str) -> None:
    for el in list(measure):
        tag = el.tag.replace(ns, "") if ns else el.tag
        if tag in ("note", "backup", "forward"):
            measure.remove(el)


def append_backup(measure: ET.Element, ns: str, dur: int) -> None:
    b = ET.Element(q(ns, "backup"))
    d = ET.SubElement(b, q(ns, "duration"))
    d.text = str(dur)
    measure.append(b)


def set_key(measure: ET.Element, ns: str, fifths: int) -> None:
    for el in measure:
        tag = el.tag.replace(ns, "") if ns else el.tag
        if tag != "attributes":
            continue
        key = el.find(q(ns, "key"))
        if key is None:
            key = ET.Element(q(ns, "key"))
            # insert after divisions if possible
            kids = list(el)
            idx = 0
            for i, ch in enumerate(kids):
                if (ch.tag.replace(ns, "") if ns else ch.tag) == "divisions":
                    idx = i + 1
                    break
            el.insert(idx, key)
        f = key.find(q(ns, "fifths"))
        if f is None:
            f = ET.SubElement(key, q(ns, "fifths"))
        f.text = str(fifths)
        return


def load(sid: str) -> tuple[ET.ElementTree, ET.Element, str]:
    path = ASSET / f"{sid}.musicxml"
    tree = ET.parse(path)
    root = tree.getroot()
    ns = ns_of(root)
    return tree, root, ns


def save(sid: str, tree: ET.ElementTree) -> None:
    path = ASSET / f"{sid}.musicxml"
    tree.write(path, encoding="utf-8", xml_declaration=True)
    THIRD.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, THIRD / f"{sid}.musicxml")
    print(f"[saved] {sid}")


def measures(root: ET.Element, ns: str) -> list[ET.Element]:
    part = root.find(q(ns, "part"))
    assert part is not None
    return part.findall(q(ns, "measure"))


def convert(sid: str) -> None:
    cmd = [
        sys.executable,
        str(ROOT / "scripts" / "musicxml_to_score.py"),
        "--id",
        sid,
        "--input",
        str(ASSET / f"{sid}.musicxml"),
        "--update-catalog",
        "--score-kind",
        "omrDraft",
    ]
    print("[convert]", sid)
    subprocess.check_call(cmd, cwd=str(ROOT))


# ---------- 1. Call of Silence ----------
def fix_sawano() -> None:
    sid = "sawano_call_of_silence"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    # divisions=8, 4/4 => whole=32, half=16, dotted-half=24, quarter=8, eighth=4
    D = 8

    def rewrite(m: ET.Element, rh: list, lh: list) -> None:
        clear_notes(m, ns)
        for spec in rh:
            m.append(make_note(ns, **spec, staff=1, voice=1))
        append_backup(m, ns, 4 * D)
        for spec in lh:
            m.append(make_note(ns, **spec, staff=2, voice=5))

    # m1: half rest + quarter rest + G4 e + A4 e | LH whole rest  (hi-res crop)
    rewrite(
        ms[0],
        [
            dict(step=None, octave=None, dur=2 * D, typ="half", rest=True),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
            dict(step="G", octave=4, dur=D // 2, typ="eighth"),
            dict(step="A", octave=4, dur=D // 2, typ="eighth"),
        ],
        [dict(step=None, octave=None, dur=4 * D, typ="whole", rest=True)],
    )
    # m2: B4 half, A4 q, G4 e A4 e | LH A2-E3-A3 whole (hi-res + prior theme)
    rewrite(
        ms[1],
        [
            dict(step="B", octave=4, dur=2 * D, typ="half"),
            dict(step="A", octave=4, dur=D, typ="quarter"),
            dict(step="G", octave=4, dur=D // 2, typ="eighth"),
            dict(step="A", octave=4, dur=D // 2, typ="eighth"),
        ],
        [
            dict(step="A", octave=2, dur=4 * D, typ="whole"),
            dict(step="E", octave=3, dur=4 * D, typ="whole", chord=True),
            dict(step="A", octave=3, dur=4 * D, typ="whole", chord=True),
        ],
    )
    # m3: D5 half, A4 e B4 e, C5 q | LH F2-C3-F3
    rewrite(
        ms[2],
        [
            dict(step="D", octave=5, dur=2 * D, typ="half"),
            dict(step="A", octave=4, dur=D // 2, typ="eighth"),
            dict(step="B", octave=4, dur=D // 2, typ="eighth"),
            dict(step="C", octave=5, dur=D, typ="quarter"),
        ],
        [
            dict(step="F", octave=2, dur=4 * D, typ="whole"),
            dict(step="C", octave=3, dur=4 * D, typ="whole", chord=True),
            dict(step="F", octave=3, dur=4 * D, typ="whole", chord=True),
        ],
    )
    # m4: B4 half, G4 q, A4 q | LH C3-G3-C4
    rewrite(
        ms[3],
        [
            dict(step="B", octave=4, dur=2 * D, typ="half"),
            dict(step="G", octave=4, dur=D, typ="quarter"),
            dict(step="A", octave=4, dur=D, typ="quarter"),
        ],
        [
            dict(step="C", octave=3, dur=4 * D, typ="whole"),
            dict(step="G", octave=3, dur=4 * D, typ="whole", chord=True),
            dict(step="C", octave=4, dur=4 * D, typ="whole", chord=True),
        ],
    )
    # m5: B4 whole | LH G2-D3-G3
    rewrite(
        ms[4],
        [dict(step="B", octave=4, dur=4 * D, typ="whole")],
        [
            dict(step="G", octave=2, dur=4 * D, typ="whole"),
            dict(step="D", octave=3, dur=4 * D, typ="whole", chord=True),
            dict(step="G", octave=3, dur=4 * D, typ="whole", chord=True),
        ],
    )
    # m6–m8: reprise m2–m4 contour
    for src, dst in ((1, 5), (2, 6), (3, 7)):
        clear_notes(ms[dst], ns)
        for el in list(ms[src]):
            tag = el.tag.replace(ns, "") if ns else el.tag
            if tag in ("note", "backup", "forward"):
                ms[dst].append(copy.deepcopy(el))
    save(sid, tree)
    convert(sid)


# ---------- 2. Ru Yuan ----------
def fix_ru_yuan() -> None:
    """PDF hi-res crop: C major 2/4; m1 G4; m2 eight 16ths C5..B4; LH broken C/G."""
    sid = "ru_yuan"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    set_key(ms[0], ns, 0)
    # divisions=12, 2/4 => bar=24, quarter=12, eighth=6, sixteenth=3
    D = 12

    def rewrite(m: ET.Element, rh: list, lh: list) -> None:
        clear_notes(m, ns)
        for spec in rh:
            m.append(make_note(ns, **spec, staff=1, voice=1))
        append_backup(m, ns, 2 * D)
        for spec in lh:
            m.append(make_note(ns, **spec, staff=2, voice=5))

    # m1: G4 q + q rest | LH C3 e G3 e (hi-res crop)
    rewrite(
        ms[0],
        [
            dict(step="G", octave=4, dur=D, typ="quarter"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
        ],
        [
            dict(step="C", octave=3, dur=D // 2, typ="eighth"),
            dict(step="G", octave=3, dur=D // 2, typ="eighth"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
        ],
    )
    six = [
        ("C", 5),
        ("D", 5),
        ("E", 5),
        ("F", 5),
        ("E", 5),
        ("D", 5),
        ("C", 5),
        ("B", 4),
    ]
    rewrite(
        ms[1],
        [dict(step=s, octave=o, dur=D // 4, typ="16th") for s, o in six],
        [
            dict(step="G", octave=2, dur=D // 2, typ="eighth"),
            dict(step="C", octave=3, dur=D // 2, typ="eighth"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
        ],
    )
    # m3: C5 B4 C5 B4 16ths + G4 e E4 e (approx from crop chain)
    rewrite(
        ms[2],
        [
            dict(step="C", octave=5, dur=D // 4, typ="16th"),
            dict(step="B", octave=4, dur=D // 4, typ="16th"),
            dict(step="C", octave=5, dur=D // 4, typ="16th"),
            dict(step="B", octave=4, dur=D // 4, typ="16th"),
            dict(step="G", octave=4, dur=D // 2, typ="eighth"),
            dict(step="E", octave=4, dur=D // 2, typ="eighth"),
        ],
        [
            dict(step="C", octave=3, dur=D // 2, typ="eighth"),
            dict(step="G", octave=3, dur=D // 2, typ="eighth"),
            dict(step="C", octave=4, dur=D // 2, typ="eighth"),
            dict(step="G", octave=3, dur=D // 2, typ="eighth"),
        ],
    )
    # m4–m5: repeat G4 + run pattern
    rewrite(
        ms[3],
        [
            dict(step="G", octave=4, dur=D, typ="quarter"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
        ],
        [
            dict(step="C", octave=3, dur=D // 2, typ="eighth"),
            dict(step="G", octave=3, dur=D // 2, typ="eighth"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
        ],
    )
    rewrite(
        ms[4],
        [dict(step=s, octave=o, dur=D // 4, typ="16th") for s, o in six],
        [
            dict(step="G", octave=2, dur=D // 2, typ="eighth"),
            dict(step="C", octave=3, dur=D // 2, typ="eighth"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
        ],
    )
    rewrite(
        ms[5],
        [
            dict(step="G", octave=4, dur=D // 2, typ="eighth"),
            dict(step="C", octave=5, dur=D // 2, typ="eighth"),
            dict(step="B", octave=4, dur=D, typ="quarter"),
        ],
        [
            dict(step="C", octave=3, dur=D // 2, typ="eighth"),
            dict(step="G", octave=3, dur=D // 2, typ="eighth"),
            dict(step="C", octave=4, dur=D // 2, typ="eighth"),
            dict(step="G", octave=3, dur=D // 2, typ="eighth"),
        ],
    )
    rewrite(
        ms[6],
        [
            dict(step="G", octave=4, dur=D, typ="quarter"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
        ],
        [
            dict(step="C", octave=3, dur=D // 2, typ="eighth"),
            dict(step="G", octave=3, dur=D // 2, typ="eighth"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
        ],
    )
    rewrite(
        ms[7],
        [dict(step=s, octave=o, dur=D // 4, typ="16th") for s, o in six],
        [
            dict(step="G", octave=2, dur=D // 2, typ="eighth"),
            dict(step="C", octave=3, dur=D // 2, typ="eighth"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
        ],
    )
    save(sid, tree)
    convert(sid)


# ---------- 3. Qing Tian LH ----------
def fix_qing_tian() -> None:
    sid = "jay_chou_qing_tian"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    # divisions=4, 4/4 => whole=16, eighth=2
    D = 4

    # PDF sys1 consensus: root-5-8-3 broken chords (not 1-5-8-5).
    patterns = [
        [("G", 2), ("D", 3), ("G", 3), ("B", 3), ("G", 3), ("D", 3), ("G", 3), ("B", 3)],
        [("E", 2), ("B", 2), ("E", 3), ("G", 3), ("E", 3), ("B", 2), ("E", 3), ("G", 3)],
        [("C", 2), ("G", 2), ("C", 3), ("E", 3), ("C", 3), ("G", 2), ("C", 3), ("E", 3)],
        [("D", 2), ("A", 2), ("D", 3), ("F", 3, 1), ("D", 3), ("A", 2), ("D", 3), ("F", 3, 1)],
    ]

    for i, pat in enumerate(patterns):
        m = ms[i]
        # keep RH rest; rewrite LH only — clear all notes/backups then rebuild
        clear_notes(m, ns)
        # RH whole rest
        m.append(
            make_note(
                ns,
                step=None,
                octave=None,
                dur=4 * D,
                typ="whole",
                staff=1,
                voice=1,
                rest=True,
            )
        )
        append_backup(m, ns, 4 * D)
        for note in pat:
            if len(note) == 3:
                step, octv, alter = note
            else:
                step, octv = note
                alter = None
            m.append(
                make_note(
                    ns,
                    step=step,
                    octave=octv,
                    alter=alter,
                    dur=D // 2,
                    typ="eighth",
                    staff=2,
                    voice=5,
                )
            )
    # m5-m8 LH should follow same G Em C D cycle while RH stays (existing melody may be wrong —
    # only fix LH for m5-8 to match cycle)
    for i, pat in enumerate(patterns):
        m = ms[4 + i]
        # extract existing RH notes (staff 1)
        rh_notes = []
        for el in list(m):
            tag = el.tag.replace(ns, "") if ns else el.tag
            if tag != "note":
                continue
            staff = el.findtext(q(ns, "staff")) or "1"
            if staff == "1":
                rh_notes.append(copy.deepcopy(el))
        clear_notes(m, ns)
        if rh_notes:
            for n in rh_notes:
                m.append(n)
        else:
            m.append(
                make_note(
                    ns,
                    step=None,
                    octave=None,
                    dur=4 * D,
                    typ="whole",
                    staff=1,
                    voice=1,
                    rest=True,
                )
            )
        append_backup(m, ns, 4 * D)
        for note in pat:
            if len(note) == 3:
                step, octv, alter = note
            else:
                step, octv = note
                alter = None
            m.append(
                make_note(
                    ns,
                    step=step,
                    octave=octv,
                    alter=alter,
                    dur=D // 2,
                    typ="eighth",
                    staff=2,
                    voice=5,
                )
            )
    save(sid, tree)
    convert(sid)


def fix_christina() -> None:
    """Intro: 6/8 dotted quarters. Hi-res + original OMR agree on D5 (not tied Bb4)."""
    sid = "christina_perri_a_thousand_years"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    # divisions=4 => eighth=2, dotted-quarter=6, bar=12
    dq, bar = 6, 12
    # RH pitches per measure (two dotted quarters each)
    rh_pitch = [
        ("D", 5, None),
        ("D", 5, None),
        ("D", 5, None),
        ("D", 5, None),
        ("E", 5, -1),
        ("D", 5, None),
        ("C", 5, None),
        ("B", 4, -1),
    ]
    lh_cycle = [
        [("B", 2, -1), ("F", 3, None)],
        [("B", 2, -1), ("F", 3, None)],
        [("G", 2, None), ("D", 3, None)],
        [("G", 2, None), ("D", 3, None)],
        [("E", 2, -1), ("B", 2, -1)],
        [("E", 2, -1), ("B", 2, -1)],
        [("F", 2, None), ("C", 3, None)],
        [("F", 2, None), ("C", 3, None)],
    ]
    for i in range(8):
        m = ms[i]
        clear_notes(m, ns)
        step, octv, alter = rh_pitch[i]
        for _ in range(2):
            m.append(
                make_note(
                    ns,
                    step=step,
                    octave=octv,
                    alter=alter,
                    dur=dq,
                    typ="quarter",
                    staff=1,
                    voice=1,
                    dotted=True,
                )
            )
        append_backup(m, ns, bar)
        chord = lh_cycle[i]
        for _beat in range(2):
            for k, (s, o, a) in enumerate(chord):
                m.append(
                    make_note(
                        ns,
                        step=s,
                        octave=o,
                        alter=a,
                        dur=dq,
                        typ="quarter",
                        staff=2,
                        voice=5,
                        dotted=True,
                        chord=(k > 0),
                    )
                )
    save(sid, tree)
    convert(sid)


def fix_xiang() -> None:
    sid = "xiang_yun_duan"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    e, bar = 4, 32

    def arp(kind: str):
        if kind == "G":
            return [
                ("G", 2, None),
                ("D", 3, None),
                ("G", 3, None),
                ("A", 3, None),
                ("B", 3, -1),
                ("A", 3, None),
                ("G", 3, None),
                ("D", 3, None),
            ]
        if kind == "Eb":
            return [
                ("E", 2, -1),
                ("B", 2, -1),
                ("E", 3, -1),
                ("F", 3, None),
                ("G", 3, None),
                ("F", 3, None),
                ("E", 3, -1),
                ("B", 2, -1),
            ]
        if kind == "F":
            return [
                ("F", 2, None),
                ("C", 3, None),
                ("F", 3, None),
                ("G", 3, None),
                ("A", 3, None),
                ("G", 3, None),
                ("F", 3, None),
                ("C", 3, None),
            ]
        return [
            ("D", 2, None),
            ("A", 2, None),
            ("D", 3, None),
            ("E", 3, None),
            ("F", 3, 1),
            ("E", 3, None),
            ("D", 3, None),
            ("A", 2, None),
        ]

    patterns = [arp("G"), arp("Eb"), arp("F"), arp("G"), arp("Eb"), arp("F"), arp("D"), arp("G")]
    for i in range(8):
        m = ms[i]
        clear_notes(m, ns)
        if i < 3:
            m.append(
                make_note(
                    ns,
                    step=None,
                    octave=None,
                    dur=bar,
                    typ="whole",
                    staff=1,
                    voice=1,
                    rest=True,
                )
            )
        elif i == 3:
            m.append(
                make_note(
                    ns, step=None, octave=None, dur=16, typ="half", staff=1, voice=1, rest=True
                )
            )
            m.append(
                make_note(
                    ns, step=None, octave=None, dur=e, typ="eighth", staff=1, voice=1, rest=True
                )
            )
            m.append(make_note(ns, step="C", octave=5, dur=e, typ="eighth", staff=1, voice=1))
            m.append(
                make_note(
                    ns, step="B", octave=4, alter=-1, dur=e, typ="eighth", staff=1, voice=1
                )
            )
            m.append(
                make_note(
                    ns, step=None, octave=None, dur=8, typ="quarter", staff=1, voice=1, rest=True
                )
            )
        elif i == 4:
            m.append(
                make_note(
                    ns, step="B", octave=4, alter=-1, dur=2, typ="16th", staff=1, voice=1
                )
            )
            m.append(
                make_note(
                    ns, step="B", octave=4, alter=-1, dur=2, typ="16th", staff=1, voice=1
                )
            )
            m.append(make_note(ns, step="C", octave=5, dur=e, typ="eighth", staff=1, voice=1))
            m.append(make_note(ns, step="D", octave=5, dur=e, typ="eighth", staff=1, voice=1))
            m.append(make_note(ns, step="C", octave=5, dur=e, typ="eighth", staff=1, voice=1))
            m.append(
                make_note(
                    ns, step="B", octave=4, alter=-1, dur=16, typ="half", staff=1, voice=1
                )
            )
        else:
            m.append(
                make_note(
                    ns,
                    step=None,
                    octave=None,
                    dur=bar,
                    typ="whole",
                    staff=1,
                    voice=1,
                    rest=True,
                )
            )
        append_backup(m, ns, bar)
        for step, octv, alter in patterns[i]:
            m.append(
                make_note(
                    ns,
                    step=step,
                    octave=octv,
                    alter=alter,
                    dur=e,
                    typ="eighth",
                    staff=2,
                    voice=5,
                )
            )
    save(sid, tree)
    convert(sid)


def fix_jue() -> None:
    sid = "jue_bie_shu"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    qn, en, bar = 4, 2, 16
    motif = [
        dict(step="F", octave=5, dur=qn, typ="quarter"),
        dict(step="E", octave=5, dur=en, typ="eighth"),
        dict(step="D", octave=5, dur=en, typ="eighth"),
        dict(step=None, octave=None, dur=8, typ="half", rest=True),
    ]
    lh_f = [
        dict(step="F", octave=2, dur=qn, typ="quarter"),
        dict(step=None, octave=None, dur=12, typ="half", rest=True, dotted=True),
    ]

    def rewrite(m, rh, lh):
        clear_notes(m, ns)
        for spec in rh:
            m.append(make_note(ns, **spec, staff=1, voice=1))
        append_backup(m, ns, bar)
        for spec in lh:
            m.append(make_note(ns, **spec, staff=2, voice=5))

    for i in range(0, 8, 2):
        rewrite(ms[i], motif, lh_f)
        rewrite(
            ms[i + 1],
            [dict(step="C", octave=5, dur=bar, typ="whole")],
            [dict(step=None, octave=None, dur=bar, typ="whole", rest=True)],
        )
    save(sid, tree)
    convert(sid)


def fix_haru() -> None:
    sid = "haruhikage"
    tree, root, ns = load(sid)
    for part in root.findall(q(ns, "part")):
        set_key(part.find(q(ns, "measure")), ns, 4)
    p3 = next(p for p in root.findall(q(ns, "part")) if p.get("id") == "P3")
    ms = p3.findall(q(ns, "measure"))
    e, dq, bar = 2, 6, 12
    rh_chords = [
        [("B", 3, None), ("E", 4, None), ("G", 4, 1)],
        [("B", 3, None), ("E", 4, None), ("G", 4, 1)],
        [("B", 3, None), ("D", 4, 1), ("F", 4, 1)],
        [("B", 3, None), ("E", 4, None), ("G", 4, 1)],
        [("B", 3, None), ("E", 4, None), ("G", 4, 1)],
        [("B", 3, None), ("E", 4, None), ("G", 4, 1)],
        [("B", 3, None), ("D", 4, 1), ("F", 4, 1)],
        [("B", 3, None), ("E", 4, None), ("G", 4, 1)],
    ]
    lh_chords = [
        [("E", 2, None), ("B", 2, None), ("E", 3, None)],
        [("C", 2, 1), ("G", 2, 1), ("C", 3, 1)],
        [("A", 1, None), ("E", 2, None), ("A", 2, None)],
        [("B", 1, None), ("F", 2, 1), ("B", 2, None)],
        [("E", 2, None), ("B", 2, None), ("E", 3, None)],
        [("C", 2, 1), ("G", 2, 1), ("C", 3, 1)],
        [("A", 1, None), ("E", 2, None), ("A", 2, None)],
        [("B", 1, None), ("F", 2, 1), ("B", 2, None)],
    ]
    for i in range(8):
        m = ms[i]
        clear_notes(m, ns)
        for k, (step, octv, alter) in enumerate(rh_chords[i]):
            m.append(
                make_note(
                    ns,
                    step=step,
                    octave=octv,
                    alter=alter,
                    dur=dq,
                    typ="quarter",
                    staff=1,
                    voice=1,
                    dotted=True,
                    chord=(k > 0),
                )
            )
        for _ in range(3):
            m.append(make_note(ns, step="B", octave=3, dur=e, typ="eighth", staff=1, voice=1))
        append_backup(m, ns, bar)
        if i >= 4:
            base = lh_chords[i]
            for _ in range(2):
                for step, octv, alter in base:
                    m.append(
                        make_note(
                            ns,
                            step=step,
                            octave=octv,
                            alter=alter,
                            dur=e,
                            typ="eighth",
                            staff=2,
                            voice=5,
                        )
                    )
        else:
            for k, (step, octv, alter) in enumerate(lh_chords[i]):
                m.append(
                    make_note(
                        ns,
                        step=step,
                        octave=octv,
                        alter=alter,
                        dur=bar,
                        typ="half",
                        staff=2,
                        voice=5,
                        dotted=True,
                        chord=(k > 0),
                    )
                )
    save(sid, tree)
    convert(sid)


def fix_castle_end() -> None:
    sid = "hisaishi_castle_in_the_sky"
    tree, root, ns = load(sid)
    part = root.find(q(ns, "part"))
    ms = part.findall(q(ns, "measure"))
    last = ms[-1]
    bar = 24
    new_m = ET.Element(q(ns, "measure"))
    new_m.set("number", str(int(last.get("number")) + 1))
    new_m.append(make_note(ns, step="A", octave=4, dur=bar, typ="whole", staff=1, voice=1))
    append_backup(new_m, ns, bar)
    new_m.append(make_note(ns, step="A", octave=2, dur=bar, typ="whole", staff=2, voice=5))
    bl = ET.SubElement(new_m, q(ns, "barline"))
    bl.set("location", "right")
    bs = ET.SubElement(bl, q(ns, "bar-style"))
    bs.text = "light-heavy"
    part.append(new_m)
    save(sid, tree)
    convert(sid)


def fix_castle_mid() -> None:
    """Rewrite numbered measures 7–18 to PDF mid crop (LH F3 E3 A2 D3 G2 C3 ×2)."""
    sid = "hisaishi_castle_in_the_sky"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    by_num = {m.get("number"): m for m in ms}
    q, e, dh, w = 6, 3, 18, 24

    def rewrite(m, rh, lh_pitch):
        clear_notes(m, ns)
        for s in rh:
            m.append(make_note(ns, **s, staff=1, voice=1))
        append_backup(m, ns, w)
        step, octv = lh_pitch
        m.append(make_note(ns, step=step, octave=octv, dur=w, typ="whole", staff=2, voice=5))

    lh_cycle = [("F", 3), ("E", 3), ("A", 2), ("D", 3), ("G", 2), ("C", 3)]
    bars_rh = [
        [
            dict(step="A", octave=4, dur=dh, typ="half", dotted=True),
            dict(step="G", octave=4, dur=q, typ="quarter"),
        ],
        [
            dict(step="F", octave=4, dur=q, typ="quarter"),
            dict(step="E", octave=4, dur=e, typ="eighth"),
            dict(step="D", octave=4, alter=1, dur=e, typ="eighth"),
            dict(step="E", octave=4, dur=e, typ="eighth"),
            dict(step="G", octave=4, dur=e, typ="eighth"),
            dict(step=None, octave=None, dur=q, typ="quarter", rest=True),
        ],
        [
            dict(step="C", octave=5, dur=dh, typ="half", dotted=True),
            dict(step="B", octave=4, dur=q, typ="quarter"),
        ],
        [
            dict(step="A", octave=4, dur=dh, typ="half", dotted=True),
            dict(step="G", octave=4, dur=q, typ="quarter"),
        ],
        [
            dict(step="F", octave=4, dur=q, typ="quarter"),
            dict(step="E", octave=4, dur=e, typ="eighth"),
            dict(step="D", octave=4, dur=e, typ="eighth"),
            dict(step="E", octave=4, dur=e, typ="eighth"),
            dict(step="G", octave=4, dur=e, typ="eighth"),
            dict(step=None, octave=None, dur=q, typ="quarter", rest=True),
        ],
        [
            dict(step="C", octave=5, dur=dh, typ="half", dotted=True),
            dict(step="B", octave=4, dur=q, typ="quarter"),
        ],
    ]
    bars_rh2 = [
        bars_rh[0],
        [
            dict(step="F", octave=4, dur=q, typ="quarter"),
            dict(step="E", octave=4, dur=e, typ="eighth"),
            dict(step="D", octave=4, dur=e, typ="eighth"),
            dict(step="E", octave=4, dur=e, typ="eighth"),
            dict(step="A", octave=4, dur=e, typ="eighth"),
            dict(step=None, octave=None, dur=q, typ="quarter", rest=True),
        ],
        [
            dict(step="C", octave=5, dur=q, typ="quarter"),
            dict(step="B", octave=4, dur=e, typ="eighth"),
            dict(step="A", octave=4, dur=e, typ="eighth"),
            dict(step="B", octave=4, dur=q, typ="quarter"),
            dict(step="E", octave=4, dur=q, typ="quarter"),
        ],
        [
            dict(step="G", octave=4, dur=e, typ="eighth"),
            dict(step="F", octave=4, dur=e, typ="eighth"),
            dict(step="E", octave=4, dur=e, typ="eighth"),
            dict(step="E", octave=4, dur=e, typ="eighth"),
            dict(step="F", octave=4, dur=e, typ="eighth"),
            dict(step="D", octave=4, alter=1, dur=e, typ="eighth"),
            dict(step="E", octave=4, dur=e, typ="eighth"),
            dict(step="F", octave=4, dur=e, typ="eighth"),
        ],
        bars_rh[0],
        [
            dict(step="F", octave=4, dur=e, typ="eighth"),
            dict(step="G", octave=4, dur=e, typ="eighth"),
            dict(step="A", octave=4, dur=e, typ="eighth"),
            dict(step="G", octave=4, dur=e, typ="eighth"),
            dict(step="A", octave=4, dur=e, typ="eighth"),
            dict(step="B", octave=4, dur=e, typ="eighth"),
            dict(step="C", octave=5, dur=q, typ="quarter"),
        ],
    ]
    # Restore measure 6 if prior off-by-one clobber (opening phrase end: E4 / G2)
    if "6" in by_num:
        rewrite(
            by_num["6"],
            [dict(step="E", octave=4, dur=w, typ="whole")],
            ("G", 2),
        )
    for i, rh in enumerate(bars_rh):
        num = str(7 + i)
        if num not in by_num:
            raise SystemExit(f"missing measure {num}")
        rewrite(by_num[num], rh, lh_cycle[i])
    for i, rh in enumerate(bars_rh2):
        num = str(13 + i)
        rewrite(by_num[num], rh, lh_cycle[i])
    save(sid, tree)
    convert(sid)


def fix_suzume() -> None:
    """220dpi crop: m1 C5 + G5 dotted-e/G5 16th + E5/D5/C5 + E5/C5/E5; LH rest. Tempo 80."""
    sid = "radwimps_suzume"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    by_num = {m.get("number"): m for m in ms}
    # divisions=12
    q, e, s, de, h, w = 12, 6, 3, 9, 24, 48
    set_key(by_num[ms[0].get("number")], ns, 0)

    def rewrite(m, rh):
        clear_notes(m, ns)
        for spec in rh:
            m.append(make_note(ns, **spec, staff=1, voice=1))
        append_backup(m, ns, w)
        m.append(
            make_note(
                ns,
                step=None,
                octave=None,
                dur=w,
                typ="whole",
                staff=2,
                voice=5,
                rest=True,
            )
        )

    # Set tempo on first measure
    first = by_num.get("0") or by_num.get("1") or ms[0]
    for el in first.iter():
        tag = el.tag.replace(ns, "") if ns else el.tag
        if tag == "per-minute":
            el.text = "80"
        if tag == "sound" and "tempo" in el.attrib:
            el.attrib["tempo"] = "80.0"

    motif_a = [
        dict(step="C", octave=5, dur=q, typ="quarter"),
        dict(step="G", octave=5, dur=de, typ="eighth", dotted=True),
        dict(step="G", octave=5, dur=s, typ="16th"),
        dict(step="E", octave=5, dur=e, typ="eighth"),
        dict(step="D", octave=5, dur=s, typ="16th"),
        dict(step="C", octave=5, dur=s, typ="16th"),
        dict(step="E", octave=5, dur=e, typ="eighth"),
        dict(step="C", octave=5, dur=s, typ="16th"),
        dict(step="E", octave=5, dur=s, typ="16th"),
    ]
    motif_b = [
        dict(step="C", octave=5, dur=e, typ="eighth"),
        dict(step="D", octave=5, dur=s, typ="16th"),
        dict(step="E", octave=5, dur=s, typ="16th"),
        dict(step="F", octave=5, dur=e, typ="eighth"),
        dict(step="E", octave=5, dur=s, typ="16th"),
        dict(step="D", octave=5, dur=s, typ="16th"),
        dict(step="C", octave=5, dur=h, typ="half"),
    ]
    # Prefer numbered 0–3 if present (this score has measure 0), else 1–4
    nums = ["0", "1", "2", "3"] if "0" in by_num else ["1", "2", "3", "4"]
    patterns = [motif_a, motif_b, motif_a, motif_b]
    for num, pat in zip(nums, patterns):
        rewrite(by_num[num], pat)
    # repeat on next four if exist
    more = ["4", "5", "6", "7"] if "0" in by_num else ["5", "6", "7", "8"]
    for num, pat in zip(more, patterns):
        if num in by_num:
            rewrite(by_num[num], pat)
    save(sid, tree)
    convert(sid)


def fix_rush_m4() -> None:
    sid = "rush_e"
    tree, root, ns = load(sid)
    m = next(mm for mm in measures(root, ns) if mm.get("number") == "4")
    clear_notes(m, ns)
    qn, en, bar = 8, 4, 32
    for spec in [
        dict(step=None, octave=None, dur=en, typ="eighth", rest=True),
        dict(step="E", octave=4, dur=en, typ="eighth"),
        dict(step=None, octave=None, dur=en, typ="eighth", rest=True),
        dict(step="E", octave=4, dur=en, typ="eighth"),
        dict(step="E", octave=3, dur=qn, typ="quarter"),
        dict(step=None, octave=None, dur=en, typ="eighth", rest=True),
        dict(step="E", octave=3, dur=en, typ="eighth"),
    ]:
        m.append(make_note(ns, **spec, staff=1, voice=1))
    append_backup(m, ns, bar)
    for spec in [
        dict(step="E", octave=2, dur=qn, typ="quarter"),
        dict(step=None, octave=None, dur=en, typ="eighth", rest=True),
        dict(step="E", octave=2, dur=en, typ="eighth"),
        dict(step=None, octave=None, dur=qn, typ="quarter", rest=True),
        dict(step=None, octave=None, dur=en, typ="eighth", rest=True),
        dict(step="E", octave=1, dur=en, typ="eighth"),
    ]:
        m.append(make_note(ns, **spec, staff=2, voice=5))
    save(sid, tree)
    convert(sid)


def fix_clayderman() -> None:
    """PDF: Bb key ♩=72; m1 three q rests + 16th rest + D5 Eb5; keep LH if present."""
    sid = "clayderman_reve_damour"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    m1 = next(m for m in ms if m.get("number") == "1")
    # divisions=8 => qdur=8, 16th=2, whole=32
    qdur, sdur, bar = 8, 2, 32
    # preserve LH notes
    lh = []
    for el in list(m1):
        tag = el.tag.replace(ns, "") if ns else el.tag
        if tag != "note":
            continue
        if (el.findtext(q(ns, "staff")) or "1") == "2":
            lh.append(copy.deepcopy(el))
    clear_notes(m1, ns)
    for spec in [
        dict(step=None, octave=None, dur=qdur, typ="quarter", rest=True),
        dict(step=None, octave=None, dur=qdur, typ="quarter", rest=True),
        dict(step=None, octave=None, dur=qdur, typ="quarter", rest=True),
        dict(step=None, octave=None, dur=sdur, typ="16th", rest=True),
        dict(step="D", octave=5, dur=sdur, typ="16th"),
        dict(step="E", octave=5, alter=-1, dur=sdur, typ="16th"),
    ]:
        m1.append(make_note(ns, **spec, staff=1, voice=1))
    # duration so far: 8*3 + 2*3 = 30 — need 32; add 16th rest
    m1.append(
        make_note(
            ns,
            step=None,
            octave=None,
            dur=sdur,
            typ="16th",
            staff=1,
            voice=1,
            rest=True,
        )
    )
    append_backup(m1, ns, bar)
    if lh:
        for n in lh:
            m1.append(n)
    else:
        m1.append(make_note(ns, step="G", octave=2, dur=bar, typ="whole", staff=2, voice=5))
    save(sid, tree)
    convert(sid)


def fix_bumble_oct() -> None:
    """PDF opens ~A5; OMR P3/m1 starts E6 — lower only octave>=5 notes in P3 m1."""
    sid = "rimsky_flight_of_the_bumblebee"
    tree, root, ns = load(sid)
    for part in root.findall(q(ns, "part")):
        if part.get("id") != "P3":
            continue
        for m in part.findall(q(ns, "measure")):
            if m.get("number") != "1":
                continue
            for el in m.findall(q(ns, "note")):
                pitch = el.find(q(ns, "pitch"))
                if pitch is None:
                    continue
                oct_el = pitch.find(q(ns, "octave"))
                if oct_el is None or not oct_el.text:
                    continue
                ov = int(oct_el.text)
                if ov >= 5:
                    oct_el.text = str(ov - 1)
            break
    save(sid, tree)
    convert(sid)


def main() -> None:
    which = sys.argv[1:] or [
        "sawano",
        "ru_yuan",
        "qing_tian",
        "christina",
        "xiang",
        "jue",
        "haru",
        "castle_end",
        "rush_m4",
    ]
    mapping = {
        "sawano": fix_sawano,
        "ru_yuan": fix_ru_yuan,
        "qing_tian": fix_qing_tian,
        "christina": fix_christina,
        "xiang": fix_xiang,
        "jue": fix_jue,
        "haru": fix_haru,
        "castle_end": fix_castle_end,
        "castle_mid": fix_castle_mid,
        "suzume": fix_suzume,
        "rush_m4": fix_rush_m4,
        "clayderman": fix_clayderman,
        "bumble": fix_bumble_oct,
    }
    for name in which:
        print("===", name, "===")
        mapping[name]()


if __name__ == "__main__":
    main()

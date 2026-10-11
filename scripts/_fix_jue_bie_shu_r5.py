"""Rewrite jue_bie_shu m69-76 and m85-88 from PDF evidence (R5). Not MIDI.

Evidence: docs/omr_audit/_jue_bie_shu_proof/r5_p3_s4.png (print 69),
r5_p3_fine1.png (73), r5_p4_fine1.png (85). Keeps omrDraft.
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


def pitch_el(step: str, octave: int, alter: int | None = None) -> ET.Element:
    p = ET.Element("pitch")
    ET.SubElement(p, "step").text = step
    if alter is not None:
        ET.SubElement(p, "alter").text = str(alter)
    ET.SubElement(p, "octave").text = str(octave)
    return p


def note(
    step: str,
    octave: int,
    dur: int,
    typ: str,
    *,
    staff: int,
    voice: int,
    alter: int | None = None,
    chord: bool = False,
    dot: bool = False,
) -> ET.Element:
    n = ET.Element("note")
    if chord:
        ET.SubElement(n, "chord")
    n.append(pitch_el(step, octave, alter))
    ET.SubElement(n, "duration").text = str(dur)
    ET.SubElement(n, "voice").text = str(voice)
    ET.SubElement(n, "type").text = typ
    if dot:
        ET.SubElement(n, "dot")
    ET.SubElement(n, "staff").text = str(staff)
    return n


def backup(dur: int = 16) -> ET.Element:
    b = ET.Element("backup")
    ET.SubElement(b, "duration").text = str(dur)
    return b


def clear_notes(m: ET.Element) -> None:
    for el in list(m):
        if local(el.tag) in ("note", "backup", "forward"):
            m.remove(el)


def append_all(m: ET.Element, els: list[ET.Element]) -> None:
    for el in els:
        m.append(el)


def lead_long(a, b, c, long_p) -> list[ET.Element]:
    """16th + 16th + 8th + dotted half (m65-style grace into long)."""
    return [
        note(*a, 1, "16th", staff=1, voice=1),
        note(*b, 1, "16th", staff=1, voice=1),
        note(*c, 2, "eighth", staff=1, voice=1),
        note(*long_p, 12, "half", staff=1, voice=1, dot=True),
    ]


def bass_chord_x4(bass, chord_tones) -> list[ET.Element]:
    """(bass 8th + triad 8th) x4 — F-major oom-pah for m69-71."""
    out: list[ET.Element] = []
    for _ in range(4):
        out.append(note(*bass, 2, "eighth", staff=2, voice=5))
        first = True
        for t in chord_tones:
            out.append(
                note(*t, 2, "eighth", staff=2, voice=5, chord=not first)
            )
            first = False
    return out


def sixteenths(pitches: list[tuple]) -> list[ET.Element]:
    return [note(*p, 1, "16th", staff=1, voice=1) for p in pitches]


def eighths(pitches: list[tuple]) -> list[ET.Element]:
    return [note(*p, 2, "eighth", staff=1, voice=1) for p in pitches]


def lh_bass_chords(bass: tuple, chord: list[tuple], n_chords: int = 3) -> list[ET.Element]:
    """Bass quarter (opt octave) + n_chords quarter triads → fill 4/4."""
    out: list[ET.Element] = []
    if len(bass) == 2 and isinstance(bass[0], tuple):
        # ((step,oct),(step,oct)) octave
        out.append(note(*bass[0], 4, "quarter", staff=2, voice=5))
        out.append(note(*bass[1], 4, "quarter", staff=2, voice=5, chord=True))
    else:
        out.append(note(*bass, 4, "quarter", staff=2, voice=5))
    for _ in range(n_chords):
        first = True
        for t in chord:
            out.append(
                note(*t, 4, "quarter", staff=2, voice=5, chord=not first)
            )
            first = False
    return out


def build_measures() -> dict[int, list[ET.Element]]:
    F2, F3, A3, C4 = ("F", 2), ("F", 3), ("A", 3), ("C", 4)
    Bb5 = ("B", 5, -1)
    fac = [F3, A3, C4]

    m: dict[int, list[ET.Element]] = {}

    # --- m69-72: PDF p3 print 69 system ---
    m[69] = (
        lead_long(("D", 5), ("E", 5), ("F", 5), ("F", 5))
        + [backup()]
        + bass_chord_x4(F2, fac)
    )
    m[70] = (
        [
            note("G", 5, 1, "16th", staff=1, voice=1),
            note("A", 5, 1, "16th", staff=1, voice=1),
            note("B", 5, 2, "eighth", staff=1, voice=1, alter=-1),
            note("B", 5, 12, "half", staff=1, voice=1, alter=-1, dot=True),
        ]
        + [backup()]
        + bass_chord_x4(F2, fac)
    )
    m[71] = (
        [
            note("B", 5, 1, "16th", staff=1, voice=1, alter=-1),
            note("C", 6, 1, "16th", staff=1, voice=1),
            note("D", 6, 2, "eighth", staff=1, voice=1),
            note("D", 6, 12, "half", staff=1, voice=1, dot=True),
        ]
        + [backup()]
        + bass_chord_x4(F2, fac)
    )
    m[72] = (
        [
            note("F", 6, 2, "eighth", staff=1, voice=1),
            note("A", 6, 2, "eighth", staff=1, voice=1, chord=True),
            note("F", 6, 2, "eighth", staff=1, voice=1),
            note("A", 6, 2, "eighth", staff=1, voice=1, chord=True),
            note("F", 6, 12, "half", staff=1, voice=1, dot=True),
        ]
        + [backup()]
        + [
            note("F", 2, 12, "half", staff=2, voice=5, dot=True),
            note("F", 1, 12, "half", staff=2, voice=5, chord=True, dot=True),
        ]
    )

    # --- m73-76: PDF p3 print 73 — RH runs + oom-pah (fill 4/4) ---
    m[73] = (
        sixteenths([("A", 4), ("G", 4), ("F", 4), ("E", 4)])
        + eighths([("F", 4), ("A", 4), ("C", 5), ("A", 4), ("F", 4), ("A", 4)])
        + [backup()]
        + bass_chord_x4(F2, fac)
    )
    m[74] = (
        sixteenths([("G", 4), ("F", 4), ("E", 4), ("D", 4)])
        + [
            note("E", 4, 2, "eighth", staff=1, voice=1),
            note("G", 4, 2, "eighth", staff=1, voice=1),
            note("B", 4, 2, "eighth", staff=1, voice=1, alter=-1),
            note("G", 4, 2, "eighth", staff=1, voice=1),
            note("E", 4, 2, "eighth", staff=1, voice=1),
            note("G", 4, 2, "eighth", staff=1, voice=1),
        ]
        + [backup()]
        + bass_chord_x4(("C", 2), [("E", 3), ("G", 3), ("C", 4)])
    )
    m[75] = (
        sixteenths([("F", 4), ("E", 4), ("D", 4), ("C", 4)])
        + eighths([("D", 4), ("F", 4), ("A", 4), ("F", 4), ("D", 4), ("F", 4)])
        + [backup()]
        + bass_chord_x4(("D", 2), [("F", 3), ("A", 3), ("D", 4)])
    )
    m[76] = (
        sixteenths([("G", 4), ("F", 4), ("E", 4), ("D", 4)])
        + [
            note("E", 4, 2, "eighth", staff=1, voice=1),
            note("C", 5, 2, "eighth", staff=1, voice=1),
            note("B", 4, 2, "eighth", staff=1, voice=1, alter=-1),
            note("G", 4, 2, "eighth", staff=1, voice=1),
            note("E", 4, 2, "eighth", staff=1, voice=1),
            note("C", 5, 2, "eighth", staff=1, voice=1),
        ]
        + [backup()]
        + bass_chord_x4(("C", 2), [("E", 3), ("G", 3), ("C", 4)])
    )

    # --- m85-88: PDF p4 print 85 — 16th runs + bass/chord ---
    dfa = [("D", 3), ("F", 3), ("A", 3)]
    m[85] = (
        sixteenths(
            [
                ("D", 5),
                ("E", 5),
                ("F", 5),
                ("G", 5),
                ("A", 5),
                ("G", 5),
                ("F", 5),
                ("G", 5),
                ("A", 5),
                ("C", 6),
                ("A", 5),
                ("G", 5),
                ("F", 5),
                ("A", 5),
                ("G", 5),
                ("F", 5),
            ]
        )
        + [backup()]
        + lh_bass_chords((("D", 2), ("D", 3)), dfa, 3)
    )
    m[86] = (
        sixteenths(
            [
                ("A", 5),
                ("G", 5),
                ("F", 5),
                ("E", 5),
                ("D", 5),
                ("E", 5),
                ("D", 5),
                ("C", 5),
            ]
        )
        + [note("D", 5, 8, "half", staff=1, voice=1)]
        + [backup()]
        + lh_bass_chords((("A", 1), ("A", 2)), [("C", 3), ("E", 3), ("A", 3)], 3)
    )
    m[87] = (
        sixteenths(
            [
                ("F", 5),
                ("G", 5),
                ("A", 5),
                ("B", 5),
                ("C", 6),
                ("B", 5),
                ("A", 5),
                ("B", 5),
                ("C", 6),
                ("E", 6),
                ("C", 6),
                ("B", 5),
                ("A", 5),
                ("B", 5),
                ("C", 6),
                ("B", 5),
            ]
        )
        + [backup()]
        + lh_bass_chords((("F", 2), ("F", 3)), fac, 3)
    )
    # Bb alters in m87
    fixed87: list[ET.Element] = []
    seq = [
        ("F", 5, None),
        ("G", 5, None),
        ("A", 5, None),
        ("B", 5, -1),
        ("C", 6, None),
        ("B", 5, -1),
        ("A", 5, None),
        ("B", 5, -1),
        ("C", 6, None),
        ("E", 6, -1),  # Eb accidental on PDF
        ("C", 6, None),
        ("B", 5, -1),
        ("A", 5, None),
        ("B", 5, -1),
        ("C", 6, None),
        ("B", 5, -1),
    ]
    for step, octv, alt in seq:
        fixed87.append(
            note(step, octv, 1, "16th", staff=1, voice=1, alter=alt)
        )
    m[87] = fixed87 + [backup()] + lh_bass_chords((("F", 2), ("F", 3)), fac, 3)

    m[88] = (
        [
            note("C", 6, 1, "16th", staff=1, voice=1),
            note("B", 5, 1, "16th", staff=1, voice=1, alter=-1),
            note("A", 5, 1, "16th", staff=1, voice=1),
            note("G", 5, 1, "16th", staff=1, voice=1),
            note("F", 5, 1, "16th", staff=1, voice=1),
            note("G", 5, 1, "16th", staff=1, voice=1),
            note("F", 5, 1, "16th", staff=1, voice=1),
            note("E", 5, 1, "16th", staff=1, voice=1),
            note("F", 5, 8, "half", staff=1, voice=1),
        ]
        + [backup()]
        + lh_bass_chords((("C", 2), ("C", 3)), [("E", 3), ("G", 3), ("C", 4)], 3)
    )

    return m


def main() -> int:
    tree = ET.parse(ASSET)
    root = tree.getroot()
    ns = root.tag.split("}")[0] + "}" if root.tag.startswith("{") else ""

    def q(name: str) -> str:
        return f"{ns}{name}" if ns else name

    part = root.find(q("part"))
    assert part is not None
    by_num = {int(m.get("number")): m for m in part.findall(q("measure"))}
    built = build_measures()
    for num, els in built.items():
        m = by_num[num]
        clear_notes(m)
        append_all(m, els)
        print(f"rewrote m{num} elements={len(els)}")

    tree.write(ASSET, encoding="utf-8", xml_declaration=True)
    for dest in SYNC_XML:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ASSET, dest)
        print("copied xml ->", dest.relative_to(REPO))

    r = subprocess.run(
        [
            sys.executable,
            str(REPO / "scripts/musicxml_to_score.py"),
            "--id",
            "jue_bie_shu",
        ],
        cwd=REPO,
        check=False,
    )
    if r.returncode != 0:
        print("musicxml_to_score failed", r.returncode)
        return r.returncode
    src_json = REPO / "assets/scores/jue_bie_shu.json"
    for dest in SYNC_JSON:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_json, dest)
        print("copied json ->", dest.relative_to(REPO))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

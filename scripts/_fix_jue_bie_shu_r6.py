"""Rewrite jue_bie_shu m77-80 and m89-96 from PDF (R6). Not MIDI."""
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


def dyad_x8(a: tuple, b: tuple) -> list[ET.Element]:
    """Eight eighth dyads filling 4/4."""
    out: list[ET.Element] = []
    for _ in range(8):
        out.append(note(*a, 2, "eighth", staff=2, voice=5))
        out.append(note(*b, 2, "eighth", staff=2, voice=5, chord=True))
    return out


def bass_chord_x4(bass: tuple, chord: list[tuple]) -> list[ET.Element]:
    out: list[ET.Element] = []
    for _ in range(4):
        out.append(note(*bass, 2, "eighth", staff=2, voice=5))
        first = True
        for t in chord:
            out.append(note(*t, 2, "eighth", staff=2, voice=5, chord=not first))
            first = False
    return out


def sixteenths(seq: list[tuple]) -> list[ET.Element]:
    return [
        note(p[0], p[1], 1, "16th", staff=1, voice=1, alter=p[2] if len(p) > 2 else None)
        for p in seq
    ]


def eighths(seq: list[tuple]) -> list[ET.Element]:
    out: list[ET.Element] = []
    for p in seq:
        if isinstance(p[0], tuple):
            # chord of pitches
            first = True
            for t in p:
                out.append(
                    note(
                        t[0],
                        t[1],
                        2,
                        "eighth",
                        staff=1,
                        voice=1,
                        alter=t[2] if len(t) > 2 else None,
                        chord=not first,
                    )
                )
                first = False
        else:
            out.append(
                note(
                    p[0],
                    p[1],
                    2,
                    "eighth",
                    staff=1,
                    voice=1,
                    alter=p[2] if len(p) > 2 else None,
                )
            )
    return out


def build() -> dict[int, list[ET.Element]]:
    m: dict[int, list[ET.Element]] = {}

    # --- m77-80: PDF p3 print 77 ---
    m[77] = (
        [note("F", 4, 2, "eighth", staff=1, voice=1)]
        + sixteenths(
            [
                ("G", 4),
                ("F", 4),
                ("E", 4),
                ("F", 4),
                ("A", 4),
                ("F", 4),
                ("G", 4),
                ("F", 4),
                ("A", 4),
                ("F", 4),
                ("E", 4),
                ("F", 4),
            ]
        )
        + [note("F", 4, 2, "eighth", staff=1, voice=1)]
        + [backup()]
        + dyad_x8(("F", 3), ("C", 4))
    )
    m[78] = (
        sixteenths(
            [
                ("G", 4),
                ("F", 4),
                ("E", 4),
                ("D", 4),
                ("F", 4),
                ("E", 4),
                ("D", 4),
                ("C", 4),
                ("E", 4),
                ("D", 4),
                ("C", 4),
                ("B", 3, -1),
                ("D", 4),
                ("C", 4),
                ("B", 3, -1),
                ("A", 3),
            ]
        )
        + [backup()]
        + [
            note("D", 3, 2, "eighth", staff=2, voice=5),
            note("F", 3, 2, "eighth", staff=2, voice=5, chord=True),
            note("D", 3, 2, "eighth", staff=2, voice=5),
            note("F", 3, 2, "eighth", staff=2, voice=5, chord=True),
            note("D", 3, 2, "eighth", staff=2, voice=5),
            note("F", 3, 2, "eighth", staff=2, voice=5, chord=True),
            note("D", 3, 2, "eighth", staff=2, voice=5),
            note("F", 3, 2, "eighth", staff=2, voice=5, chord=True),
            note("D", 3, 8, "half", staff=2, voice=5),
        ]
    )
    m[79] = (
        eighths(
            [
                ("F", 4),
                ("G", 4),
                ("A", 4),
                ("B", 4, -1),
                ("C", 5),
                ("B", 4, -1),
                ("A", 4),
                ("G", 4),
            ]
        )
        + [backup()]
        + [
            x
            for _ in range(8)
            for x in (
                note("B", 2, 2, "eighth", staff=2, voice=5, alter=-1),
                note("D", 3, 2, "eighth", staff=2, voice=5, chord=True),
            )
        ]
    )
    m[80] = (
        sixteenths(
            [
                ("A", 4),
                ("G", 4),
                ("F", 4),
                ("E", 4),
                ("G", 4),
                ("F", 4),
                ("E", 4),
                ("D", 4),
                ("F", 4),
                ("E", 4),
                ("D", 4),
                ("C", 4),
            ]
        )
        + [
            note("G", 3, 2, "eighth", staff=1, voice=1),
            note("G", 4, 2, "eighth", staff=1, voice=1, chord=True),
            note("C", 4, 2, "eighth", staff=1, voice=1),
            note("E", 4, 2, "eighth", staff=1, voice=1, chord=True),
            note("G", 4, 2, "eighth", staff=1, voice=1, chord=True),
        ]
        + [backup()]
        + [
            note("C", 3, 2, "eighth", staff=2, voice=5),
            note("E", 3, 2, "eighth", staff=2, voice=5, chord=True),
            note("G", 3, 2, "eighth", staff=2, voice=5, chord=True),
            note("C", 3, 2, "eighth", staff=2, voice=5),
            note("E", 3, 2, "eighth", staff=2, voice=5, chord=True),
            note("G", 3, 2, "eighth", staff=2, voice=5, chord=True),
            note("C", 3, 2, "eighth", staff=2, voice=5),
            note("E", 3, 2, "eighth", staff=2, voice=5, chord=True),
            note("G", 3, 2, "eighth", staff=2, voice=5, chord=True),
            note("G", 2, 2, "eighth", staff=2, voice=5),
            note("C", 2, 4, "quarter", staff=2, voice=5),
        ]
    )

    # --- m89-92: PDF p4 print 89 ---
    # RH: D6/F5 alternating eighths (grace omitted → short reattack)
    # LH: D2 + DFA ×4
    dfa = [("D", 3), ("F", 3), ("A", 3)]

    def high_alt(top: str, top_oct: int, bot: str = "F", bot_oct: int = 5, n: int = 8):
        out: list[ET.Element] = []
        for i in range(n):
            if i % 2 == 0:
                out.append(note(top, top_oct, 2, "eighth", staff=1, voice=1))
            else:
                out.append(note(bot, bot_oct, 2, "eighth", staff=1, voice=1))
        return out

    m[89] = (
        [
            note("D", 6, 2, "eighth", staff=1, voice=1),
            note("F", 5, 2, "eighth", staff=1, voice=1),
            note("C", 6, 2, "eighth", staff=1, voice=1),
            note("F", 5, 2, "eighth", staff=1, voice=1),
            note("B", 5, 2, "eighth", staff=1, voice=1, alter=-1),
            note("F", 5, 2, "eighth", staff=1, voice=1),
            note("A", 5, 2, "eighth", staff=1, voice=1),
            note("F", 5, 2, "eighth", staff=1, voice=1),
        ]
        + [backup()]
        + bass_chord_x4(("D", 2), dfa)
    )

    def m89_like() -> list[ET.Element]:
        return (
            [
                note("D", 6, 2, "eighth", staff=1, voice=1),
                note("F", 5, 2, "eighth", staff=1, voice=1),
                note("C", 6, 2, "eighth", staff=1, voice=1),
                note("F", 5, 2, "eighth", staff=1, voice=1),
                note("B", 5, 2, "eighth", staff=1, voice=1, alter=-1),
                note("F", 5, 2, "eighth", staff=1, voice=1),
                note("A", 5, 2, "eighth", staff=1, voice=1),
                note("F", 5, 2, "eighth", staff=1, voice=1),
            ]
            + [backup()]
            + bass_chord_x4(("D", 2), dfa)
        )

    m[90] = m89_like()
    m[91] = m89_like()
    m[92] = (
        [
            note("D", 4, 16, "whole", staff=1, voice=1),
            note("F", 4, 16, "whole", staff=1, voice=1, chord=True),
            note("A", 4, 16, "whole", staff=1, voice=1, chord=True),
        ]
        + [backup()]
        + [
            note("D", 1, 16, "whole", staff=2, voice=5),
            note("D", 2, 16, "whole", staff=2, voice=5, chord=True),
        ]
    )

    # --- m93-96: PDF p4 print 93 ---
    fac = [("A", 3), ("C", 4), ("F", 4)]

    def m93_like() -> list[ET.Element]:
        fa_eights: list[ET.Element] = []
        for _ in range(8):
            fa_eights.append(note("F", 6, 2, "eighth", staff=1, voice=1))
            fa_eights.append(note("A", 6, 2, "eighth", staff=1, voice=1, chord=True))
        return fa_eights + [backup()] + bass_chord_x4(("F", 2), fac)

    m[93] = m93_like()
    m[94] = m93_like()
    m[95] = m93_like()
    m[96] = (
        [
            note("F", 5, 16, "whole", staff=1, voice=1),
            note("A", 5, 16, "whole", staff=1, voice=1, chord=True),
        ]
        + [backup()]
        + [
            note("F", 2, 16, "whole", staff=2, voice=5),
            note("A", 3, 16, "whole", staff=2, voice=5, chord=True),
            note("C", 4, 16, "whole", staff=2, voice=5, chord=True),
            note("F", 4, 16, "whole", staff=2, voice=5, chord=True),
        ]
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
    for num, els in build().items():
        m = by_num[num]
        clear_notes(m)
        for el in els:
            m.append(el)
        print(f"rewrote m{num} n={len(els)}")

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
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
